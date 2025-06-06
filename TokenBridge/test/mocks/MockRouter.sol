//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IRouterClient} from "@chainlink/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/src/v0.8/ccip/libraries/Client.sol";

contract MockRouter is IRouterClient {

    uint256 public fees;

    function setFee(uint256 _fee) external {
        fees = _fee;
    }

    function getFee(uint64 /*destinationChainSelector*/,
        Client.EVM2AnyMessage memory /*message*/) external view returns(uint256) {

        return fees;
    }

    function ccipSend(uint64 /*destinationChainSelector*/,
        Client.EVM2AnyMessage memory /*message*/) external payable returns(bytes32) {
            return keccak256("0x1234");
        }

    function getSupportedTokens(uint64) external pure returns (address[] memory) {
        return new address[](0);
    }

    function isChainSupported(uint64) external pure returns (bool) {
        return true;
    }

}