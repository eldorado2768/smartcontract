// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IFlashLoanBorrower {
    function executeFlashLoan(address _token, uint256 _amount) external;
}
