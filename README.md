# ZKsync NFT Auction House

A Solidity-based NFT marketplace that combines **ERC-721 NFTs**, **English-style auctions**, **NFT escrow**, **pull-based ETH payments**, **platform fees**, and **ZKsync Era Sepolia** deployment.

The project is designed as a practical mid-level Web3 portfolio project demonstrating how a decentralized auction protocol can manage NFT ownership, bidding, refunds, settlement, and platform fees entirely through smart contracts.

> **Status:** Portfolio / Educational Project
> **Network:** ZKsync Era Sepolia
> **Language:** Solidity
> **License:** MIT

---

## Overview

The ZKsync NFT Auction House allows users to:

1. Mint an ERC-721 NFT.
2. Approve the auction contract to manage the NFT.
3. Create a timed auction.
4. Deposit the NFT into smart-contract escrow.
5. Receive bids in ETH.
6. Account for previous bidders' refundable balances.
7. Settle the auction after it expires.
8. Transfer the NFT to the winner.
9. Distribute sale proceeds between the seller and platform treasury.
10. Withdraw accumulated ETH securely.

The project focuses on the smart-contract layer rather than building an unnecessarily complex frontend or protocol.

---

# Key Features

### NFT Collection

* ERC-721 implementation
* NFT minting
* Token URI metadata
* Maximum NFT supply
* Configurable mint price
* Owner-controlled withdrawal

### Auction System

* English-style ascending auctions
* Configurable starting price
* Configurable auction duration
* Minimum bid increment
* Highest bidder tracking
* Auction expiration
* Auction settlement
* No-bid settlement
* Auction cancellation before bidding

### Payment System

* ETH-based bidding
* Pull-payment refund architecture
* Pending withdrawal accounting
* Seller proceeds
* Platform fees
* Configurable treasury
* Configurable platform fee

### Security

* OpenZeppelin contracts
* `ReentrancyGuard`
* `Ownable`
* Custom Solidity errors
* NFT escrow
* Pull-based payments
* Checks before state-changing operations
* No direct refund transfer during bidding

### Testing

The project includes automated Hardhat tests covering:

* NFT minting
* NFT metadata
* NFT ownership
* NFT approval
* Auction creation
* NFT escrow
* Minimum bid requirements
* Multiple bidders
* Previous bidder refunds
* Auction settlement
* Platform fee accounting
* No-bid auctions
* Auction cancellation
* Withdrawal functionality
* Invalid auction actions

---

# Architecture

```text
                         ┌───────────────────┐
                         │       User        │
                         └─────────┬─────────┘
                                   │
                                   │ mint()
                                   ▼
                    ┌──────────────────────────┐
                    │     ZKsyncGallery        │
                    │                          │
                    │      ERC-721 NFT         │
                    │      Token Metadata      │
                    └────────────┬─────────────┘
                                 │
                                 │ approve()
                                 ▼
                    ┌──────────────────────────┐
                    │    EnglishAuction        │
                    │                          │
                    │   Auction Management     │
                    │   NFT Escrow             │
                    │   Bid Accounting         │
                    │   Settlement             │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────┴─────────────┐
                    │                          │
                    ▼                          ▼
             ┌──────────────┐          ┌───────────────┐
             │    Bidders   │          │    Seller     │
             │              │          │               │
             │ ETH Bids     │          │ Sale Proceeds │
             └──────┬───────┘          └───────────────┘
                    │
                    │ previous bids
                    ▼
             ┌──────────────────┐
             │ Pending          │
             │ Withdrawals      │
             └────────┬─────────┘
                      │
                      │ withdraw()
                      ▼
                   Bidder
```

---

# Smart Contracts

## `ZKsyncGallery.sol`

The NFT contract implements an ERC-721 collection using OpenZeppelin.

### Responsibilities

* NFT minting
* Token URI management
* Supply management
* Mint price management
* Contract balance withdrawal

### Main Functions

```solidity
mint(string calldata uri)
```

Mints a new NFT to the caller.

```solidity
setMintPrice(uint256 newPrice)
```

Allows the contract owner to update the mint price.

```solidity
withdraw()
```

Allows the contract owner to withdraw accumulated minting revenue.

---

# `EnglishAuction.sol`

The auction contract manages the complete auction lifecycle.

### Responsibilities

* NFT escrow
* Auction creation
* Bid management
* Bid validation
* Refund accounting
* Auction settlement
* Platform fees
* Seller proceeds
* Withdrawals

---

# Auction Lifecycle

## 1. Mint NFT

The seller first mints an NFT.

```solidity
mint("ipfs://metadata")
```

The NFT initially belongs to the seller.

---

## 2. Approve Auction Contract

The seller approves the auction contract:

```solidity
approve(
    auctionAddress,
    tokenId
)
```

This allows the auction contract to transfer the NFT into escrow.

---

## 3. Create Auction

The seller creates an auction:

```solidity
createAuction(
    tokenId,
    startPrice,
    duration
)
```

The NFT is transferred from:

```text
Seller
   ↓
EnglishAuction Contract
```

The auction contract becomes the temporary custodian of the NFT.

---

## 4. Place Bid

A bidder submits ETH:

```solidity
bid(auctionId)
```

The contract checks that the bid satisfies the minimum required amount.

The minimum increment is:

```text
5%
```

For example:

```text
Current Bid: 1 ETH

Minimum Next Bid:
1 ETH × 1.05 = 1.05 ETH
```

---

# Pull Payment System

The project deliberately avoids sending ETH directly to previous bidders during the `bid()` transaction.

Instead, the previous bidder receives an internal credit:

```solidity
pendingWithdrawals[previousBidder] += previousBid;
```

The bidder can later withdraw:

```solidity
withdraw();
```

This follows the pull-payment pattern and separates auction state transitions from external ETH transfers.

---

# Auction Settlement

After the auction expires:

```solidity
settleAuction(auctionId)
```

The contract determines whether there was a winning bid.

### If there is a winner

The NFT is transferred:

```text
Auction Contract
       │
       │ NFT
       ▼
     Winner
```

The winning ETH is divided between:

```text
Winning Bid
     │
     ├───────────────┐
     ▼               ▼
 Seller           Treasury
 proceeds         platform fee
```

The default platform fee is:

```text
2.5%
```

Both seller proceeds and the platform fee are recorded using the pull-payment system.

---

# Example

Suppose an NFT sells for:

```text
1 ETH
```

Platform fee:

```text
2.5%
```

Platform receives:

```text
0.025 ETH
```

Seller receives:

```text
0.975 ETH
```

Both balances can subsequently be withdrawn by their respective accounts.

---

# No-Bid Auctions

If an auction expires without receiving a bid:

```text
Auction
   │
   │ no bids
   ▼
Settlement
   │
   ▼
NFT returned to seller
```

No ETH distribution occurs.

---

# Auction Cancellation

A seller can cancel an auction before the first bid is placed.

Once a bid exists, cancellation is blocked.

This prevents the seller from arbitrarily removing an active auction after users have committed funds.

---

# Security Considerations

The project uses several common Solidity security patterns.

## Reentrancy Protection

Functions that move ETH are protected using OpenZeppelin's:

```solidity
ReentrancyGuard
```

This is particularly relevant to:

```solidity
withdraw()
settleAuction()
cancelAuction()
```

---

## Pull Payments

Instead of transferring ETH to previous bidders during bidding, the contract records their balances.

```solidity
mapping(address => uint256)
    public pendingWithdrawals;
```

Users withdraw their funds themselves.

---

## Access Control

Administrative operations use OpenZeppelin's:

```solidity
Ownable
```

This protects configuration functions such as:

```solidity
setMintPrice()
setFeeConfig()
```

---

## NFT Escrow

During an active auction, the NFT is held by the auction contract.

This prevents the seller from transferring the NFT elsewhere while it is being auctioned.

---

## Custom Errors

The contracts use Solidity custom errors such as:

```solidity
error AuctionNotFound();
error AuctionEnded();
error BidTooLow();
error AlreadySettled();
error HasActiveBid();
```

Custom errors provide structured failure handling and reduce revert-data overhead compared with many string-based revert messages.

---

# Technology Stack

| Technology         | Purpose                         |
| ------------------ | ------------------------------- |
| Solidity           | Smart contract development      |
| OpenZeppelin       | ERC-721 and security primitives |
| Hardhat            | Development and testing         |
| Ethers.js          | Blockchain interaction          |
| JavaScript         | Deployment and tests            |
| ZKsync Era         | Layer-2 deployment              |
| ZKsync Era Sepolia | Testnet                         |
| Git                | Version control                 |
| GitHub             | Source control and portfolio    |

---

# Project Structure

```text
zksync-nft-auction/
│
├── contracts/
│   ├── EnglishAuction.sol
│   └── ZKsyncGallery.sol
│
├── scripts/
│   └── deploy.js
│
├── test/
│   └── AuctionHouse.test.js
│
├── .env.example
├── .gitignore
├── hardhat.config.js
├── package.json
├── requirements.txt
├── LICENSE
└── README.md
```

---

# Requirements

Install:

```text
Node.js >= 20
npm >= 10
```

Project dependencies include:

```text
Hardhat
Ethers.js
OpenZeppelin Contracts
dotenv
Chai
```

---

# Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/zksync-nft-auction.git
```

Move into the project:

```bash
cd zksync-nft-auction
```

Install dependencies:

```bash
npm install
```

---

# Compile

Compile the smart contracts:

```bash
npm run compile
```

---

# Run Tests

Run the complete test suite:

```bash
npm test
```

The tests execute against Hardhat's local blockchain.

---

# Local Deployment

Deploy locally:

```bash
npm run deploy:local
```

The deployment script deploys:

```text
ZKsyncGallery
        ↓
EnglishAuction
```

The auction contract is configured with:

```text
NFT Contract
Treasury Address
2.5% Platform Fee
```

---

# ZKsync Era Sepolia

The project is configured for ZKsync Era Sepolia.

Network:

```text
ZKsync Era Sepolia
```

Chain ID:

```text
300
```

RPC:

```text
https://sepolia.era.zksync.dev
```

---

# Environment Configuration

Create a local `.env` file:

```bash
cp .env.example .env
```

Then configure:

```env
WALLET_PRIVATE_KEY=0xYOUR_TESTNET_PRIVATE_KEY
```

Never commit `.env`.

The repository includes:

```text
.env.example
```

instead.

---

# Deploy to ZKsync Era Sepolia

After configuring your testnet wallet:

```bash
npm run deploy:zksync
```

The deployment script will output:

```text
Deploying with: 0x...

ZKsyncGallery: 0x...

EnglishAuction: 0x...
```

Save the contract addresses for future interaction and contract verification.

---

# Environment Variables

| Variable             | Description                |
| -------------------- | -------------------------- |
| `WALLET_PRIVATE_KEY` | Testnet wallet private key |

Only use a wallet created specifically for development/testing.

Never use a wallet containing meaningful funds.

---

# Testing Strategy

The test suite follows the main protocol lifecycle:

```text
Mint
  ↓
Approve
  ↓
Create Auction
  ↓
Place Bid
  ↓
Place Higher Bid
  ↓
Refund Previous Bidder
  ↓
Auction Expiry
  ↓
Settlement
  ↓
NFT Transfer
  ↓
ETH Withdrawal
```

The tests also verify invalid state transitions.

Examples:

```text
Bid below minimum
Cancel after bidding
Settle before expiration
Settle twice
Invalid auction
Invalid withdrawal
```

---

# Events

The contracts emit events for important protocol actions.

### NFT Mint

```solidity
event ArtworkMinted(
    address indexed to,
    uint256 indexed tokenId,
    string tokenURI
);
```

### Auction Creation

```solidity
event AuctionCreated(
    uint256 indexed auctionId,
    uint256 indexed tokenId,
    address indexed seller,
    uint256 startPrice,
    uint256 endTime
);
```

### Bid

```solidity
event BidPlaced(
    uint256 indexed auctionId,
    address indexed bidder,
    uint256 amount
);
```

### Settlement

```solidity
event AuctionSettled(
    uint256 indexed auctionId,
    uint256 indexed tokenId,
    address indexed winner,
    uint256 amount
);
```

### Cancellation

```solidity
event AuctionCancelled(
    uint256 indexed auctionId
);
```

### Withdrawal

```solidity
event Withdrawal(
    address indexed account,
    uint256 amount
);
```

These events provide an event-driven interface that can later be consumed by a frontend or indexing service.

---

# Design Decisions

## Why ERC-721?

ERC-721 provides a standard representation for unique NFTs.

The auction contract can interact with NFTs through the standard interface:

```solidity
IERC721
```

---

## Why an English Auction?

The English auction model is relatively simple while still demonstrating important smart-contract concepts:

* State management
* ETH transfers
* Escrow
* Time-based conditions
* Multiple participants
* Refund accounting
* Settlement

---

## Why Pull Payments?

Directly refunding previous bidders during `bid()` would introduce an external ETH transfer into the bidding process.

The pull-payment design separates:

```text
Auction Logic
```

from:

```text
Withdrawal Logic
```

This provides a common security pattern for handling refunds.

---

## Why ZKsync?

ZKsync Era provides an Ethereum-compatible Layer-2 environment.

Deploying the protocol to ZKsync demonstrates experience beyond a purely local Ethereum/Hardhat environment.

---

# Future Improvements

Possible extensions include:

### NFT Royalties

Implement:

```text
ERC-2981
```

to support creator royalty information.

### ERC-20 Bidding

Allow auctions to accept an ERC-20 token instead of native ETH.

### Anti-Sniping

Extend an auction automatically when a bid arrives near the deadline.

Example:

```text
Auction ends: 20:00

Bid arrives: 19:59:30

New ending time:
20:02:30
```

### Frontend

Build a React interface using:

```text
React
TypeScript
wagmi
viem
```

### Event Indexing

Add an indexing layer for:

```text
Auctions
Bids
NFTs
Transactions
Users
```

### Advanced Testing

Add:

```text
Foundry
Fuzz Testing
Invariant Testing
```

### Contract Verification

Verify deployed contracts on the appropriate ZKsync block explorer.

---

# What This Project Demonstrates

This project demonstrates practical knowledge of:

* Solidity
* EVM smart contracts
* ERC-721
* OpenZeppelin
* Contract inheritance
* Interfaces
* Mappings
* Structs
* Events
* Modifiers
* Custom errors
* Payable functions
* ETH transfers
* Escrow
* Auction state machines
* Time-based logic
* Pull-payment architecture
* Reentrancy protection
* Access control
* Smart-contract testing
* Hardhat
* Ethers.js
* ZKsync Era
* Layer-2 deployment
* Git/GitHub workflow

---

# Resume Entry

## ZKsync NFT Auction House

**Solidity | OpenZeppelin | Hardhat | Ethers.js | ZKsync Era**

Built a Solidity-based NFT auction marketplace implementing ERC-721 minting, timed English auctions, NFT escrow, bid accounting, pull-based refunds, configurable platform fees, access control, reentrancy protection, and automated smart-contract testing. Configured the protocol for deployment on ZKsync Era Sepolia.

---

# License

This project is licensed under the MIT License.

See [`LICENSE`](LICENSE) for details.

---

# Disclaimer

This project is intended for educational and portfolio purposes.

It has not undergone a professional smart-contract security audit and should not be used with meaningful funds in its current form.
