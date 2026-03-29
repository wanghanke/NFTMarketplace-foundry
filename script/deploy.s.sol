// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/MyNFT.sol";
import "../src/MyNFTFactory.sol";

import "../src/NFTAuction.sol";
import "../src/NFTAuctionFactory.sol";

contract DeployAll is Script {

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        /**
         * Deploy MyNFT Implementation
         */
        MyNFT myNFTImplementation = new MyNFT();

        console.log("MyNFT implementation:",address(myNFTImplementation));


        /**
         * Deploy MyNFTFactory
         */
        MyNFTFactory myNFTFactory = new MyNFTFactory(address(myNFTImplementation),  msg.sender);

        console.log( "MyNFTFactory:",address(myNFTFactory));

        /**
         * Deploy NFTAuction Implementation
         */
        NFTAuction auctionImplementation = new NFTAuction();

        console.log( "NFTAuction implementation:",address(auctionImplementation));

        /**
         *  Deploy NFTAuctionFactory
         */
        address platformFeeReceiver = msg.sender;

        NFTAuctionFactory auctionFactory = new NFTAuctionFactory(address(auctionImplementation), platformFeeReceiver, msg.sender);

        console.log("NFTAuctionFactory:", address(auctionFactory));


        /**
         *  create nft proxy
         */
        address nftProxy = myNFTFactory.createNFT("MyFT","wq");

        console.log("Sample NFT proxy:", nftProxy);

        /**
         *  create auction proxy
         */
        address auctionProxy = auctionFactory.createAuction();

        console.log("Sample Auction proxy:", auctionProxy);

        vm.stopBroadcast();
    }
}