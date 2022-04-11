pragma solidity >=0.8.0;

interface IVestingEscrow {
	function deposit(address account, uint amount) external;
}