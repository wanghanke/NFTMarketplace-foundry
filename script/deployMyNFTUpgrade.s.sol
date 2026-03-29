// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/MyNFT.sol";

contract UpgradeMyNFT is Script {

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");

        address proxyAddress = vm.envAddress("MYNFT_PROXY");

        vm.startBroadcast(deployerPrivateKey);

        /**
         *  Deploy new implementation
         */
        MyNFT newImplementation = new MyNFT();
        console.log("MyNFT newImplementation:",address(newImplementation));

        /**
         *  Upgrade proxy -> new implementation
         */
        MyNFT(proxyAddress).upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();
    }
}