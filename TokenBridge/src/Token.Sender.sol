// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IRouterClient} from "@chainlink/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {Client} from "@chainlink/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/src/v0.8/ccip/libraries/Client.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";




contract CCIPTokenSender is Ownable {
    using SafeERC20 for IERC20;

    error CCIPTokenSender__InsufficientBalance(IERC20 token, uint256 currentBalance, uint256 requiredAmount);
    error CCIPTokenSender__NothingToWithdraw();

    IRouterClient private  CCIP_ROUTER;
    IERC20 private LINK_TOKEN;
    IERC20 private USDC_TOKEN;
    uint64 private constant DESTINATION_CHAIN_SELECTOR = 10344971235874465080;

    event USDCBrigded (
        bytes32 messageId,
        uint64 indexed destinationChainSelector,
        address indexed receiver,
        uint256 amount,
        uint256 ccipFee
    );

    constructor(
        address _router,
        address _linkToken,
        address _usdcToken
        ) Ownable(msg.sender) {
            CCIP_ROUTER = IRouterClient(_router);
            LINK_TOKEN = IERC20(_linkToken);
            USDC_TOKEN = IERC20(_usdcToken);
    }

    function transferTokens(
    address _receiver,
    uint256 _amount
) external returns (bytes32 messageId) {
    uint256 userBalance = USDC_TOKEN.balanceOf(msg.sender);
    if (_amount > userBalance) {
        revert CCIPTokenSender__InsufficientBalance(
            USDC_TOKEN,
            userBalance,
            _amount
        );
    }

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({
        token: address(USDC_TOKEN),
        amount: _amount
    });

    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
        receiver: abi.encode(_receiver),
        data: "",
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})),
        feeToken: address(LINK_TOKEN)
    });

    uint256 ccipFee = CCIP_ROUTER.getFee(DESTINATION_CHAIN_SELECTOR, message);
    
    if (ccipFee > LINK_TOKEN.balanceOf(address(this))) {
        revert CCIPTokenSender__InsufficientBalance(
            LINK_TOKEN,
            LINK_TOKEN.balanceOf(address(this)),
            ccipFee
        );
    }

    LINK_TOKEN.approve(address(CCIP_ROUTER), ccipFee);
    USDC_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
    USDC_TOKEN.approve(address(CCIP_ROUTER), _amount);

    messageId = CCIP_ROUTER.ccipSend(DESTINATION_CHAIN_SELECTOR, message);
    emit USDCBrigded(messageId, DESTINATION_CHAIN_SELECTOR, _receiver, _amount, ccipFee);
}
    function withdrawToken(
        address _beneficiary
    ) public onlyOwner {
        uint256 amount = IERC20(USDC_TOKEN).balanceOf(address(this));
        if (amount == 0) revert CCIPTokenSender__NothingToWithdraw();
        IERC20(USDC_TOKEN).transfer(_beneficiary, amount);
    }
}