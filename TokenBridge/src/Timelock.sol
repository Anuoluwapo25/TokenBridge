//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";



contract Timelock {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public count = 0;
    uint256 public constant LOCK_PERIOD = 7 days;

    struct Pool {
        uint256 amount;
        address owner;
        bool withdrawn;
        uint256 depositTime;
    }

    constructor(IERC20 _token) {
        token = _token;
    }

    mapping(uint256 => Pool) public pools;
    mapping(address => uint256[]) public users;

    function depositeFund(uint256 _amount) external {
        require(_amount > 0, "amount must be greater than zero");

        token.transferFrom(msg.sender, address(this), _amount);

        uint256 _id = count++;

        pools[_id] = Pool({
            amount: _amount,
            owner: msg.sender,
            withdrawn: false,
            depositTime: block.timestamp
        });

        users[msg.sender].push(_id);
    }


    function withdraw(uint256 _id) external {
        Pool storage user = pools[_id];
        require(msg.sender == user.owner, "Must be owner");
        require(!user.withdrawn, "Already withdrawn");
        // require(block.timestamp - user.depositTime > LOCK_PERIOD, "Liquidity not reached");
        require(block.timestamp >= user.depositTime + LOCK_PERIOD, "Lock period not reached");

        user.withdrawn = true;
        token.safeTransfer(msg.sender, user.amount);

    }


    function getUserPoolIds(address user) external view returns(uint256[] memory) {
        return users[user];
    }


}

