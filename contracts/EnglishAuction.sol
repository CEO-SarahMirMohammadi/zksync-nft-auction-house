// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EnglishAuction is ReentrancyGuard, Ownable {
    uint256 public constant MIN_BID_INCREMENT_BPS = 500;
    uint256 public constant MAX_FEE_BPS = 1_000;

    IERC721 public immutable nft;
    address public treasury;
    uint256 public feeBps;
    uint256 public auctionCount;

    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 startPrice;
        uint256 highestBid;
        address highestBidder;
        uint64 endTime;
        bool settled;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingWithdrawals;

    error InvalidAddress();
    error InvalidDuration();
    error InvalidPrice();
    error AuctionNotFound();
    error AuctionEnded();
    error AuctionNotEnded();
    error BidTooLow();
    error AlreadySettled();
    error HasActiveBid();
    error NotSeller();

    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 startPrice,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    event AuctionSettled(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed winner,
        uint256 amount
    );

    event AuctionCancelled(uint256 indexed auctionId);

    event FeeConfigUpdated(
        address indexed treasury,
        uint256 feeBps
    );

    event Withdrawal(
        address indexed account,
        uint256 amount
    );

    constructor(
        address nftAddress,
        address treasuryAddress,
        uint256 initialFeeBps
    ) Ownable(msg.sender) {
        if (
            nftAddress == address(0) ||
            treasuryAddress == address(0)
        ) {
            revert InvalidAddress();
        }

        if (initialFeeBps > MAX_FEE_BPS) {
            revert InvalidPrice();
        }

        nft = IERC721(nftAddress);
        treasury = treasuryAddress;
        feeBps = initialFeeBps;
    }

    function createAuction(
        uint256 tokenId,
        uint256 startPrice,
        uint64 duration
    ) external returns (uint256 auctionId) {
        if (startPrice == 0) {
            revert InvalidPrice();
        }

        if (
            duration < 5 minutes ||
            duration > 30 days
        ) {
            revert InvalidDuration();
        }

        if (nft.ownerOf(tokenId) != msg.sender) {
            revert NotSeller();
        }

        nft.transferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        auctionId = ++auctionCount;

        uint64 endTime = uint64(
            block.timestamp + duration
        );

        auctions[auctionId] = Auction({
            seller: msg.sender,
            tokenId: tokenId,
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: endTime,
            settled: false
        });

        emit AuctionCreated(
            auctionId,
            tokenId,
            msg.sender,
            startPrice,
            endTime
        );
    }

    function bid(
        uint256 auctionId
    ) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (auction.seller == address(0)) {
            revert AuctionNotFound();
        }

        if (auction.settled) {
            revert AlreadySettled();
        }

        if (block.timestamp >= auction.endTime) {
            revert AuctionEnded();
        }

        uint256 minimumBid =
            auction.highestBid == 0
                ? auction.startPrice
                : auction.highestBid +
                    (
                        auction.highestBid *
                        MIN_BID_INCREMENT_BPS
                    ) /
                    10_000;

        if (msg.value < minimumBid) {
            revert BidTooLow();
        }

        if (auction.highestBidder != address(0)) {
            pendingWithdrawals[
                auction.highestBidder
            ] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(
            auctionId,
            msg.sender,
            msg.value
        );
    }

    function settleAuction(
        uint256 auctionId
    ) external nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (auction.seller == address(0)) {
            revert AuctionNotFound();
        }

        if (auction.settled) {
            revert AlreadySettled();
        }

        if (block.timestamp < auction.endTime) {
            revert AuctionNotEnded();
        }

        auction.settled = true;

        if (auction.highestBidder == address(0)) {
            nft.transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );

            emit AuctionSettled(
                auctionId,
                auction.tokenId,
                address(0),
                0
            );

            return;
        }

        uint256 fee =
            (auction.highestBid * feeBps) /
            10_000;

        uint256 sellerProceeds =
            auction.highestBid - fee;

        pendingWithdrawals[treasury] += fee;
        pendingWithdrawals[auction.seller] += sellerProceeds;

        nft.transferFrom(
            address(this),
            auction.highestBidder,
            auction.tokenId
        );

        emit AuctionSettled(
            auctionId,
            auction.tokenId,
            auction.highestBidder,
            auction.highestBid
        );
    }

    function cancelAuction(
        uint256 auctionId
    ) external nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (auction.seller == address(0)) {
            revert AuctionNotFound();
        }

        if (auction.settled) {
            revert AlreadySettled();
        }

        if (auction.seller != msg.sender) {
            revert NotSeller();
        }

        if (auction.highestBidder != address(0)) {
            revert HasActiveBid();
        }

        auction.settled = true;

        nft.transferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );

        emit AuctionCancelled(auctionId);
    }

    function withdraw() external nonReentrant {
        uint256 amount =
            pendingWithdrawals[msg.sender];

        if (amount == 0) {
            revert InvalidPrice();
        }

        pendingWithdrawals[msg.sender] = 0;

        (bool success,) =
            payable(msg.sender).call{
                value: amount
            }("");

        require(success, "Withdrawal failed");

        emit Withdrawal(
            msg.sender,
            amount
        );
    }

    function setFeeConfig(
        address newTreasury,
        uint256 newFeeBps
    ) external onlyOwner {
        if (newTreasury == address(0)) {
            revert InvalidAddress();
        }

        if (newFeeBps > MAX_FEE_BPS) {
            revert InvalidPrice();
        }

        treasury = newTreasury;
        feeBps = newFeeBps;

        emit FeeConfigUpdated(
            newTreasury,
            newFeeBps
        );
    }
}