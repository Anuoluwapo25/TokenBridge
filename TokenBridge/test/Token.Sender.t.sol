// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CCIPTokenSender} from "../src/Token.Sender.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

contract MockRouter {
    uint256 public constant MOCK_FEE = 1e18;
    
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }
    
    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }
    
    function getFee(uint64, EVM2AnyMessage memory) external pure returns (uint256) {
        return MOCK_FEE;
    }
    
    function ccipSend(uint64, EVM2AnyMessage memory) external returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender));
    }
    
    function isChainSupported(uint64) external pure returns (bool) {
        return true;
    }
    
    function getSupportedTokens(uint64) external pure returns (address[] memory) {
        return new address[](0);
    }
}

contract CCIPTokenSenderTest is Test {
    CCIPTokenSender public tokenSender;
    MockRouter public router;
    MockERC20 public link;
    MockERC20 public usdc;
    
    address public owner = makeAddr("owner");
    address public receiver = makeAddr("receiver");
    address public user = makeAddr("user");
    
    uint64 public constant DESTINATION_CHAIN_SELECTOR = 10344971235874465080;
    uint256 public constant TRANSFER_AMOUNT = 100e6;
    uint256 public constant LINK_FEE = 1e18;
    
    function setUp() public {
        vm.startPrank(owner);
        
        router = new MockRouter();
        link = new MockERC20("Chainlink", "LINK", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        
        tokenSender = new CCIPTokenSender(
            address(router),
            address(link),
            address(usdc)
        );
        
        link.mint(user, 100e18);
        usdc.mint(user, 1000e6);
        link.mint(address(tokenSender), LINK_FEE * 10);
        
        vm.stopPrank();
    }
    
    function test_successfulTransfer() public {
        vm.startPrank(user);
        
        usdc.approve(address(tokenSender), TRANSFER_AMOUNT);
        
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 contractBalanceBefore = usdc.balanceOf(address(tokenSender));
        
        console.log("User balance before:", userBalanceBefore);
        console.log("Contract balance before:", contractBalanceBefore);
        
        bytes32 messageId = tokenSender.transferTokens(receiver, TRANSFER_AMOUNT);
        
        console.log("Message ID:", uint256(messageId));
        console.log("User balance after:", usdc.balanceOf(user));
        console.log("Contract balance after:", usdc.balanceOf(address(tokenSender)));
        
        assertEq(usdc.balanceOf(user), userBalanceBefore - TRANSFER_AMOUNT);
        assertEq(usdc.balanceOf(address(tokenSender)), contractBalanceBefore + TRANSFER_AMOUNT);
        assertTrue(messageId != bytes32(0));
        
        vm.stopPrank();
    }
    
    function test_revert_insufficientUSDCBalance() public {
        vm.startPrank(user);
        
        uint256 userBalance = usdc.balanceOf(user);
        uint256 excessiveAmount = userBalance + 1;
        
        usdc.approve(address(tokenSender), type(uint256).max);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPTokenSender.CCIPTokenSender__InsufficientBalance.selector,
                address(usdc),
                userBalance,
                excessiveAmount
            )
        );
        tokenSender.transferTokens(receiver, excessiveAmount);
        
        vm.stopPrank();
    }

    function test_revertInsufficientLINKBalance() public {
        vm.startPrank(owner);
        
        CCIPTokenSender tokenSenderNoLink = new CCIPTokenSender(
            address(router),
            address(link),
            address(usdc)
        );
        
        vm.stopPrank();
        vm.startPrank(user);
        
        usdc.mint(user, TRANSFER_AMOUNT);
        usdc.approve(address(tokenSenderNoLink), TRANSFER_AMOUNT);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPTokenSender.CCIPTokenSender__InsufficientBalance.selector,
                address(link),
                0,
                LINK_FEE
            )
        );
        tokenSenderNoLink.transferTokens(receiver, TRANSFER_AMOUNT);
        
        vm.stopPrank();
    }
    
    function test_revertZeroAmount() public {
        vm.startPrank(user);
        usdc.approve(address(tokenSender), TRANSFER_AMOUNT);
        
        vm.expectRevert(CCIPTokenSender.CCIPTokenSender__InvalidAmount.selector);
        tokenSender.transferTokens(receiver, 0);
        vm.stopPrank();
    }
    
    function test_revertZeroAddressReceiver() public {
        vm.startPrank(user);
        usdc.approve(address(tokenSender), TRANSFER_AMOUNT);
        
        vm.expectRevert(CCIPTokenSender.CCIPTokenSender__InvalidReceiver.selector);
        tokenSender.transferTokens(address(0), TRANSFER_AMOUNT);
        vm.stopPrank();
    }
}