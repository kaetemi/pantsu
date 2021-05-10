// SPDX-License-Identifier: BSD-3-Clause
// Copyright (C) 2021  Jan BOON (Kaetemi) <jan.boon@kaetemi.be>

/*

This is a hyperinflationary token designed to be absolutely worthless.
I am not responsible for your losses.

For each transfer, additional tokens may be mined into the outstanding supply.
1/8 of the outstanding supply is given as a bonus for each transfer output,
with a maximum of 1/8 of the transfer value.

A faucet provides 1/64 of the outstanding supply.

The amount of tokens mined is proportional to the the number of successfully
mined blocks. Each transfer can mine one block. The number of mined blocks is
capped by the number of mined network blocks. Blocks up until deployment are
discarded.

*/

pragma solidity ^0.8.4;

interface IBEP20 {
	function totalSupply() external view returns (uint256);
	function decimals() external view returns (uint8);
	function symbol() external view returns (string memory);
	function name() external view returns (string memory);
	function getOwner() external view returns (address);
	function balanceOf(address account) external view returns (uint256);
	function transfer(address recipient, uint256 amount) external returns (bool);
	function allowance(address owner, address spender) external view returns (uint256);
	function approve(address spender, uint256 amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Pantsu is IBEP20 {
	string public override constant name = "Pantsu";
	string public override constant symbol = "PANTSU";
	uint8 public override constant decimals = 18;
	address public override constant getOwner = address(0);

	uint256 _totalSupply;
	uint256 _outstandingSupply;
	uint256 _minedBlocks;

	mapping(address => uint256) balances;
	mapping(address => mapping (address => uint256)) allowed;

	constructor() {
		_totalSupply = 0;
		_outstandingSupply = 0;
		_minedBlocks = block.number;
	}

	function totalSupply() public override view returns (uint256) {
		return _totalSupply;
	}

	function balanceOf(address account) public override view returns (uint256) {
		return balances[account];
	}

	function _maybeMine() private {
		if (_minedBlocks < block.number) {
			_minedBlocks++;
			uint256 minedAmount = _minedBlocks * (2 ** 38);
			_outstandingSupply += minedAmount;
		}
	}

	function faucet() public {
		_maybeMine();
		uint256 drop = _outstandingSupply / 64;
		_outstandingSupply -= drop;
		_totalSupply += drop;
		balances[msg.sender] += drop;
		emit Transfer(address(this), msg.sender, drop);
	}

	function faucetTo(address recipient) public {
		_maybeMine();
		if (recipient != address(this)) {
			uint256 drop = _outstandingSupply / 64;
			_outstandingSupply -= drop;
			_totalSupply += drop;
			balances[recipient] += drop;
			emit Transfer(address(this), recipient, drop);
		}
	}

	function _transferNow(address sender, address recipient, uint256 amount) private {
		balances[sender] -= amount;
		if (recipient != address(this)) {
			uint256 bonus = _outstandingSupply / 8;
			uint256 maxBonus = amount / 8;
			if (bonus > maxBonus) {
				bonus = maxBonus;
			}
			_outstandingSupply -= bonus;
			_totalSupply += bonus;
			balances[recipient] += (amount + bonus);
			emit Transfer(sender, recipient, amount);
			if (bonus > 0) {
				emit Transfer(address(this), recipient, bonus);
			}
		} else {
			_outstandingSupply += amount;
			_totalSupply -= amount;
			emit Transfer(sender, recipient, amount);
		}
	}

	function transfer(address recipient, uint256 amount) public override returns (bool) {
		require(amount <= balances[msg.sender]);
		_maybeMine();
		_transferNow(msg.sender, recipient, amount);
		return true;
	}

	function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
		require(amount <= balances[sender]);
		require(amount <= allowed[sender][msg.sender]);
		_maybeMine();
		allowed[sender][msg.sender] -= amount;
		_transferNow(sender, recipient, amount);
		return true;
	}

	function approve(address spender, uint256 amount) public override returns (bool) {
		allowed[msg.sender][spender] = amount;
		emit Approval(msg.sender, spender, amount);
		return true;
	}

	function allowance(address owner, address spender) public override view returns (uint256) {
		return allowed[owner][spender];
	}
}

/* end of file */