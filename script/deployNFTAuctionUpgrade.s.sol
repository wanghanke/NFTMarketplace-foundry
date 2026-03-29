// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/MyNFT.sol";
import {NFTAuction} from "../src/NFTAuction.sol";

contract UpgradeMyNFT is Script {

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");

        address payable proxyAddress = payable(vm.envAddress("NFTAUCTION_PROXY"));

        vm.startBroadcast(deployerPrivateKey);

        /**
         *  Deploy new implementation
         */
        NFTAuction newImplementation = new NFTAuction();
        console.log("MyNFT newImplementation:",address(myNFTImplementation));

        /**
         *  Upgrade proxy -> new implementation
         */
        NFTAuction(proxyAddress).upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();
    }
}