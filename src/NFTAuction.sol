// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC721Upgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Initializable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC2981} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

contract NFTAuction is Initializable, IERC721Receiver, OwnableUpgradeable, ReentrancyGuard, PausableUpgradeable, UUPSUpgradeable{

    struct Auction {
        /**
         * 卖家
         */
        address seller;
        /**
         * nf合约地址
         */
        address nftContract;
        /**
         * nft tokenId
         */
        uint256 tokenId;
        /**
         * 货币 用于区别是eth还是代币，address(0)表示eth
         */
        address currency;
        /**
         * 起始价格
         */
        uint256 startPrice;
        /**
         * 最高出价者
         */
        address highestBidder;
        /**
         * 最高出价
         */
        uint256 highestBid;
        /**
         * 开始时间
         */
        uint256 startTime;
        /**
         * 结束时间
         */
        uint256 endTime;
        /**
         * 是否激活
         */
        bool active;
    }

    /**
     * 拍卖数量
     */
    uint256 public auctionCount;
    /**
     * 拍卖最小增长率
     */
    uint256 public minBidIncrementBps = 500;
    /**
     * 平台手续费
     */
    uint256 public platformFee = 200;
    /**
     * 平台收款地址
     */
    address public platformFeeReceiver;
    /**
     * 拍卖信息
     */
    mapping(uint256 => Auction) public auctions;
    /**
     * auction与token关联关系，用于判断NTF是否被取消过
     */
    mapping(address => mapping(uint256 => bool)) public tokenOnAuction;
    /**
     * 出价者退款信息
     */
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    /**
     * 最长拍卖时间
     */
    uint256 public constant MAX_EXTENSION = 30 minutes;
    /**
     * 预言地址
     */
    mapping(address => AggregatorV3Interface) public priceFeeds;

    using SafeERC20 for IERC20;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, address indexed nftContract, uint256 tokenId, address currency, uint256 startPrice, uint256 startTime, uint256 endTime);
    event AuctionBid(uint256 indexed auctionId, address indexed bidder, address currency, uint256 amount, uint256 usdValue);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 finalPrice, uint256 usdValue);
    event AuctionCanceled(uint256 indexed auctionId, bool active);
    event BidWithdrawn(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event MinBidIncrementChanged(address indexed owner, uint256 oldBps, uint256 newBps);
    event PlatformFeeChanged(address indexed owner, uint256 oldBps, uint256 _newBps);
    event PlatformFeeReceiverChanged(address indexed owner, address oldReceiver, address _newReceiver);
    event Deposit(address indexed sender, uint amount);


    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address _platformFeeReceiver) public initializer {
        __Ownable_init(owner);
        __Pausable_init();
        require(_platformFeeReceiver != address(0), "Invalid fee Receiver");
        platformFeeReceiver = _platformFeeReceiver;
        minBidIncrementBps = 500;
        platformFee = 200;
    }

    function onERC721Received(address, address,uint256,bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setPriceFeed(address token, address feed) public onlyOwner {
        require(feed != address(0), "Invalid feed");
        priceFeeds[token] = AggregatorV3Interface(feed);
    }

    function createAuction(address nftContract, address currency, uint256 tokenId, uint256 startPrice, uint256 startTime, uint256 durationHours) public nonReentrant whenNotPaused {
        require(nftContract != address(0), "Invalid nftContract");
        require(nftContract.code.length > 0, "nftContract is not contract");
        require(!tokenOnAuction[nftContract][tokenId], "NFT is already on auction");
        require(IERC165(nftContract).supportsInterface(type(IERC721).interfaceId), "Not ERC721");
        IERC721 nft = IERC721(nftContract);
        address owner = msg.sender;
        require(nft.ownerOf(tokenId) == owner, "Not owner");
        require(nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(owner, address(this)), "Marketplace not approved");
        require(currency == address(0) || address(priceFeeds[currency]) != address(0) , "Unsupported currency");
        require(startPrice > 0, "Start price must bigger zero");
        require(startTime >= block.timestamp, "Invalid start time");
        uint256 endTime = startTime + durationHours * 1 hours;
        require(startTime < endTime, "Start time must low end time");

        auctionCount++;
        auctions[auctionCount] = Auction({
            seller: owner,
            nftContract: nftContract,
            tokenId: tokenId,
            currency: currency,
            startPrice: startPrice,
            highestBidder: address(0),
            highestBid: 0,
            startTime: startTime,
            endTime: endTime,
            active: true
        });

        nft.safeTransferFrom(owner, address(this), tokenId);

        tokenOnAuction[nftContract][tokenId] = true;
        emit AuctionCreated(auctionCount, msg.sender, nftContract, tokenId, currency, startPrice, startTime, endTime);
    }

    function bidAuction(uint256 auctionId, uint256 amount) public payable nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not exist");
        require(auction.active, "Auction not active");
        require(auction.startTime < block.timestamp, "Auction not start");
        require(auction.endTime > block.timestamp, "Auction end");
        address newHighestBidder = msg.sender;
        require(auction.seller != newHighestBidder, "Seller can not bid");

        uint256 minBid;
        uint256 highestBid = auction.highestBid;
        if(highestBid == 0) {
            minBid = auction.startPrice;
        } else {
            minBid = highestBid + (highestBid* minBidIncrementBps / 10000);
        }

        address currency = auction.currency;
        uint256 newHighestBid;
        if(currency == address(0)) {
            require(amount == 0, "Amount must be zero for eth bid");
            require(msg.value >= minBid, "Bid too low");
            newHighestBid = msg.value;
        } else {
            require(msg.value == 0, "Eth must be zero for ERC20");
            require(amount >= minBid, "Bid too low");
            IERC20(currency).safeTransferFrom(newHighestBidder, address(this), amount);
            newHighestBid = amount;
        }
        address highestBidder = auction.highestBidder;
        if(highestBidder != address(0)) {
            pendingReturns[auctionId][highestBidder] += auction.highestBid;
        }

        auction.highestBid = newHighestBid;
        auction.highestBidder = newHighestBidder;

        uint256 extension = 5 minutes;
        if (auction.endTime + extension - auction.startTime > MAX_EXTENSION) {
            auction.endTime = auction.startTime + MAX_EXTENSION;
        } else {
            auction.endTime += extension;
        }

        uint256 usdValue = _getUSDValue(currency, newHighestBid);

        emit AuctionBid(auctionId, newHighestBidder, currency, newHighestBid, usdValue);
    }

    function _getUSDValue(address token, uint256 amount) internal view returns (uint256) {
        AggregatorV3Interface feed = priceFeeds[token];
        require(address(feed) != address(0), "Price feed not set");
        (, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();
        require(price > 0, "Invalid oracle price");
        require(block.timestamp - updatedAt < 1 hours, "Stale Price");
        uint256 priceDecimals = feed.decimals();
        uint8 decimals;
        if(token == address(0)) {
            decimals = 18;
        } else {
            decimals = IERC20Metadata(token).decimals();
        }
        return Math.mulDiv(amount, uint256(price) * 1e18 / (10 ** priceDecimals), 10 ** decimals);
    }

    function endAuction(uint256 auctionId) public nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];
        address seller = auction.seller;
        require(seller != address(0), "Auction not exist");
        require(auction.active == true, "Auction already canceled");
        require(auction.endTime < block.timestamp, "Auction has not ended");

        auction.active = false;
        address nftContract = auction.nftContract;
        uint256 tokenId = auction.tokenId;
        address highestBidder = auction.highestBidder;
        if(highestBidder != address(0)) {
            uint256 highestBid = auction.highestBid;
            uint256 fee = highestBid * platformFee / 10000;

            address royaltyReceiver = address(0);
            uint256 royaltyAmount = 0;
            if(IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)) {
                try IERC2981(nftContract).royaltyInfo(tokenId, highestBid) returns (address receiver, uint256 amount) {
                    royaltyReceiver = receiver;
                    royaltyAmount = amount;
                } catch {}
            }
            require(royaltyAmount + fee <= highestBid, "Invalid royalty");
            uint256 sellAmount = highestBid - fee - royaltyAmount;
            address currency = auction.currency;
            if(fee > 0) {
                _safeTransfer(currency, platformFeeReceiver, fee);
            }

            if(royaltyAmount > 0 && royaltyReceiver != address(0)) {
                _safeTransfer(currency, royaltyReceiver, royaltyAmount);
            }

           _safeTransfer(currency, seller, sellAmount);

           IERC721(nftContract).safeTransferFrom(address(this), highestBidder, tokenId);

           uint256 usdValue = _getUSDValue(currency, highestBid);

           emit AuctionEnded(auctionId, highestBidder, highestBid, usdValue);
        } else {
            IERC721(nftContract).safeTransferFrom(address(this), seller, tokenId);
            emit AuctionEnded(auctionId, address(0), 0, 0);
        }

        tokenOnAuction[auction.nftContract][auction.tokenId] = false;
    }

    function _safeTransfer(address currency, address to, uint256 amount) internal {
        if(amount == 0) return;
        if(currency == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }
    }

    function cancelAuction(uint256 auctionId) public nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];
        address seller = auction.seller;
        require(seller != address(0), "Auction not exist");
        require(auction.active, "Auction already canceled");
        require(auction.endTime > block.timestamp, "Auction has ended");
        require(msg.sender == auction.seller || msg.sender == owner(), "No authorized");

        auction.active = false;

        address nftContract = auction.nftContract;
        uint256 tokenId = auction.tokenId;
        IERC721(nftContract).safeTransferFrom(address(this), seller, tokenId);

        address highestBidder = auction.highestBidder;
        if(highestBidder != address(0)) {
            pendingReturns[auctionId][highestBidder] += auction.highestBid;
        }

        tokenOnAuction[nftContract][tokenId] = false;

        emit AuctionCanceled(auctionId, auction.active);
    }

    function withdrawnBid(uint256 auctionId) public nonReentrant {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No pending return");

        pendingReturns[auctionId][msg.sender] = 0;
        address currency = auctions[auctionId].currency;
        _safeTransfer(currency, msg.sender, amount);

        emit BidWithdrawn(auctionId, msg.sender, amount);
    }

    function changeMinBidIncrementBps(uint256 _newBps) public onlyOwner {
        require(_newBps > 0 && _newBps < 2000, "Invalid newBps");
        uint256 oldBps = minBidIncrementBps;
        minBidIncrementBps = _newBps;

         emit MinBidIncrementChanged(msg.sender, oldBps, _newBps);
    }

    function changePlatformFeeBps(uint256 _newBps) external onlyOwner {
        require(_newBps > 0 && _newBps <= 1000 , "Invalid _newBps");

        uint256 oldBps = platformFee;
        platformFee = _newBps;

        emit PlatformFeeChanged(msg.sender, oldBps, _newBps);
    }

    function changePlatformFeeReceiver(address _newReceiver) external onlyOwner {
        require(_newReceiver != address(0), "Invalid newReceiver");

        address oldRecipient = platformFeeReceiver;
        platformFeeReceiver = _newReceiver;
        emit PlatformFeeReceiverChanged(msg.sender, oldRecipient, _newReceiver);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {
        uint amount = msg.value;
        if (msg.value > 0) {
            emit Deposit(msg.sender, amount);
        }
    }

    uint256[50] private __gap;
}
