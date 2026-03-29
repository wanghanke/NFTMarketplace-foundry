// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./NFTAuction.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTAuctionFactory is Ownable {
    address public implementation;
    address[] public auctions;
    mapping(address => address[]) public userNFTAuction;
    address public platformFeeReceiver;

    event NFTAuctionCreated(address indexed auctionAddress, address indexed creator, address indexed implementation);
    event ImplementationUpdated(address indexed oldImpl ,address indexed newImpl);
    event FeeReceiverUpdated(address indexed oldFeeReceiver ,address indexed newFeeReceiver);


    constructor(address _implementation, address _feeReceiver, address _owner) Ownable(_owner) {
        require(_implementation != address(0), "Invalid implementation");
        require(_implementation.code.length > 0, "Not contract");
        require(_feeReceiver != address(0), "Invalid feeReceiver");
        implementation = _implementation;
        platformFeeReceiver = _feeReceiver;
    }


    function createAuction() external returns (address) {
        require(implementation != address(0), "Implementation not set");
        require(platformFeeReceiver != address(0), "platformFeeReceiver not set");
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, abi.encodeCall(NFTAuction.initialize, (msg.sender, platformFeeReceiver)));

        auctions.push(address(proxy));
        userNFTAuction[msg.sender].push(address(proxy));
        emit NFTAuctionCreated(address(proxy), msg.sender, implementation);
        return address(proxy);
    }

    function getNFTAuctionCount() public view returns (uint256) {
            return auctions.length;
        }

    function getUserNFTAuction(address user) public view returns(address[] memory) {
        return userNFTAuction[user];
    }

    function setImplementation(address newImpl) external onlyOwner {
        require(newImpl != address(0), "Invalid implementation");
        require(newImpl.code.length > 0, "Not contract");

        address oldImpl = implementation;
        implementation = newImpl;
        emit ImplementationUpdated(oldImpl, newImpl);
    }
    function setFeeRecipient(address feeReceiver) external onlyOwner {
        require(feeReceiver != address(0), "Invalid feeReceiver");
        address oldFeeReceiver = platformFeeReceiver;
        platformFeeReceiver= feeReceiver;
        emit FeeReceiverUpdated(oldFeeReceiver ,feeReceiver);
    }
}