// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/src/v0.8/ccip/libraries/Client.sol";

contract CCIPTokenSender {
    using SafeERC20 for IERC20;

    error CCIPTokenSender__InsufficientBalance(address token, uint256 balance, uint256 amount);
    error CCIPTokenSender__TransferFailed(address token, address from, address to, uint256 amount);
    error CCIPTokenSender__InvalidReceiver();
    error CCIPTokenSender__InvalidAmount();

    IRouterClient public immutable i_router;
    IERC20 public immutable i_link;
    IERC20 public immutable i_token;

    constructor(address router, address link, address token) {
        i_router = IRouterClient(router);
        i_link = IERC20(link);
        i_token = IERC20(token);
    }

    function transferTokens(address receiver, uint256 amount) external returns (bytes32 messageId) {
        if (receiver == address(0)) revert CCIPTokenSender__InvalidReceiver();
        if (amount == 0) revert CCIPTokenSender__InvalidAmount();

        uint256 userBalance = i_token.balanceOf(msg.sender);
        if (userBalance < amount) {
            revert CCIPTokenSender__InsufficientBalance(address(i_token), userBalance, amount);
        }

        bool success = i_token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert CCIPTokenSender__TransferFailed(address(i_token), msg.sender, address(this), amount);
        }

        Client.EVMTokenAmount[] memory tokens = new Client.EVMTokenAmount[](1);
        tokens[0] = Client.EVMTokenAmount({
            token: address(i_token),
            amount: amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "",
            tokenAmounts: tokens,
            feeToken: address(i_link),
            extraArgs: ""
        });

        uint256 fee = i_router.getFee(10344971235874465080, message);
        uint256 linkBalance = i_link.balanceOf(address(this));
        if (linkBalance < fee) {
            revert CCIPTokenSender__InsufficientBalance(address(i_link), linkBalance, fee);
        }
        
        i_link.approve(address(i_router), fee);
        messageId = i_router.ccipSend(10344971235874465080, message);

        return messageId;
    }
}