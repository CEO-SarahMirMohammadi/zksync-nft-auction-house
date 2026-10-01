// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZKsyncGallery is ERC721URIStorage, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000;
    uint256 public mintPrice = 0.001 ether;

    uint256 private _nextTokenId = 1;

    error MaxSupplyReached();
    error IncorrectPayment();

    event ArtworkMinted(
        address indexed to,
        uint256 indexed tokenId,
        string tokenURI
    );

    event MintPriceUpdated(uint256 newPrice);

    constructor() ERC721("ZKsync Gallery", "ZKGA") Ownable(msg.sender) {}

    function mint(string calldata uri)
        external
        payable
        returns (uint256 tokenId)
    {
        if (_nextTokenId > MAX_SUPPLY) revert MaxSupplyReached();
        if (msg.value != mintPrice) revert IncorrectPayment();

        tokenId = _nextTokenId++;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);

        emit ArtworkMinted(msg.sender, tokenId, uri);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}