// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

interface IDex {
    function depositUSDC(uint256 _amount) external;

    function depositDAI(uint256 _amount) external;

    function buyDAI() external;

    function sellDAI() external;
}

contract FlashLoanArbitrage is FlashLoanSimpleReceiverBase {
    address payable owner;

    // Aave ERC20 Token addresses on Sepolia network
    address private immutable daiAddress =
        0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6;
    address private immutable usdcAddress =
       0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        
    address private dexContractAddress; //Set in constructor argument
    

    IERC20 private dai;
    IERC20 private usdc;
    IDex private dexContract;

    constructor(address _addressProvider,address _dexContractAddress) //add dex Contract address as a parameter of constructor
        
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
        require(_addressProvider != address(0), "FLA: Zero address provider");
        require(_dexContractAddress != address(0), "FLA: Zero DEX address");
        require(daiAddress != address(0), "FLA: Zero DAI address constant"); // Add this
        require(usdcAddress != address(0), "FLA: Zero USDC address constant"); // Add this
        
        owner = payable(msg.sender);
        dexContractAddress = _dexContractAddress; // Set the Dex contract address

        dai = IERC20(daiAddress);
        usdc = IERC20(usdcAddress);
        dexContract = IDex(dexContractAddress);
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address, //address initiator,
        bytes calldata
        //bytes calldata params
    ) external override returns (bool) {
        // Ensure the flash loan asset is one of the tokens involved in arbitrage
        // This example assumes the flash loan is taken in USDC or DAI for simplicity
        require(asset == usdcAddress || asset == daiAddress, "Unexpected flash loan asset");

        // The logic here needs to be more robust.
        // If 'asset' is USDC, then deposit USDC to Dex, buy DAI, sell DAI for USDC, repay.
        // If 'asset' is DAI, then deposit DAI to Dex, sell DAI for USDC, buy DAI for USDC, repay.
        // The current logic in the provided `executeOperation` assumes the arbitrage
        // starts with USDC, but the flash loan could be in either.

        // For simplicity, let's assume the flash loan is taken in USDC for this example
        // The 'amount' variable holds the USDC received from the flash loan.

        // 1. Approve Dex to spend the flash-loaned USDC
        IERC20(asset).approve(dexContractAddress, amount);
        
        // 2. Deposit flash-loaned USDC into Dex
        // This line assumes 'asset' is USDC. If it could be DAI, you'd need a conditional.
        dexContract.depositUSDC(amount);

        // 3. Buy DAI with the deposited USDC
        dexContract.buyDAI(); // This consumes the deposited USDC balance in the Dex

        // 4. Deposit received DAI from the buy operation back into Dex
        // This transfers the DAI from FlashLoanArbitrage contract to its balance on Dex
        dexContract.depositDAI(dai.balanceOf(address(this))); 

        // 5. Sell DAI for USDC
        // This consumes the deposited DAI balance in the Dex
        dexContract.sellDAI(); 
        
        // At this point, the FlashLoanArbitrage contract should have a USDC balance
        // that's hopefully more than the 'amountOwed' if arbitrage was profitable.

        // Repay the flash loan
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed); // Approve Aave Pool to pull funds

        // Transfer profit to owner (optional, but good practice)
        // This assumes profit is in the 'asset' token
        uint256 currentBalance = IERC20(asset).balanceOf(address(this));
        if (currentBalance > amountOwed) {
            IERC20(asset).transfer(owner, currentBalance - amountOwed);
        }

        return true;
    }

    function requestFlashLoan(address _token, uint256 _amount) public {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    function approveUSDC(uint256 _amount) external returns (bool) {
        return usdc.approve(dexContractAddress, _amount);
    }

    function allowanceUSDC() external view returns (uint256) {
        return usdc.allowance(address(this), dexContractAddress);
    }

    function approveDAI(uint256 _amount) external returns (bool) {
        return dai.approve(dexContractAddress, _amount);
    }

    function allowanceDAI() external view returns (uint256) {
        return dai.allowance(address(this), dexContractAddress);
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    receive() external payable {}
}