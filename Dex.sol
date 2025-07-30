// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Dex {
    using SafeERC20 for IERC20;

    address payable public owner;

    // Aave ERC20 Token addresses on Sepolia network (used for type casting)
    address private immutable DAI_ADDRESS;
    address private immutable USDC_ADDRESS;

    // Swap fee (e.g., 0.3% = 3/1000)
    uint256 public constant SWAP_FEE_NUMERATOR = 3;
    uint256 public constant SWAP_FEE_DENOMINATOR = 1000; // 0.3%

    event LiquidityAdded(address indexed token, uint256 amount);
    event TokenBought(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event TokenSold(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _daiAddress, address _usdcAddress) {
        require(_daiAddress != address(0), "Dex: Zero DAI address");
        require(_usdcAddress != address(0), "Dex: Zero USDC address");
        owner = payable(msg.sender);
        DAI_ADDRESS = _daiAddress;
        USDC_ADDRESS = _usdcAddress;
    }

    /**
     * @notice Allows the owner to add initial liquidity to the DEX pools.
     * This simulates providing tokens to the Automated Market Maker (AMM).
     * @param _tokenAddress The address of the token to add liquidity for.
     * @param _amount The amount of tokens to add.
     */
    function addLiquidity(address _tokenAddress, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Dex: Amount must be greater than zero");
        require(_tokenAddress == DAI_ADDRESS || _tokenAddress == USDC_ADDRESS, "Dex: Unsupported token for liquidity");

        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        emit LiquidityAdded(_tokenAddress, _amount);
    }

    /**
     * @notice Simulates buying _tokenOut with _tokenIn using a constant product formula (x*y=k).
     * Includes a swap fee.
     * @param _tokenIn The address of the token being sent into the DEX.
     * @param _tokenOut The address of the token being received from the DEX.
     * @param _amountIn The amount of _tokenIn to swap.
     * @return amountOut The amount of _tokenOut received.
     */
    function buyToken(address _tokenIn, address _tokenOut, uint256 _amountIn) external view returns (uint256 amountOut) {
        require(_amountIn > 0, "Dex: Amount in must be greater than zero");
        require(_tokenIn != _tokenOut, "Dex: Cannot swap same tokens");
        require((_tokenIn == DAI_ADDRESS && _tokenOut == USDC_ADDRESS) || (_tokenIn == USDC_ADDRESS && _tokenOut == DAI_ADDRESS), "Dex: Unsupported token pair");

        uint256 reserveIn = IERC20(_tokenIn).balanceOf(address(this));
        uint256 reserveOut = IERC20(_tokenOut).balanceOf(address(this));

        require(reserveIn > 0 && reserveOut > 0, "Dex: Insufficient liquidity in pool");

        // Calculate amountIn after swap fee
        uint256 amountInAfterFee = _amountIn * (SWAP_FEE_DENOMINATOR - SWAP_FEE_NUMERATOR) / SWAP_FEE_DENOMINATOR;

        // Constant product formula: (reserveIn + amountInAfterFee) * (reserveOut - amountOut) = reserveIn * reserveOut
        // amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee)
        amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);

        require(amountOut > 0, "Dex: Swap resulted in zero output");
        require(reserveOut >= amountOut, "Dex: Insufficient output token liquidity");

        // In a real DEX, transfers would happen here. For this mock, we just return the calculated amount.
        // We are marking this as `view` for now, so actual transfers are commented out.
        // If you remove `view` and want real transfers, uncomment these:
        // IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        // IERC20(_tokenOut).safeTransfer(msg.sender, amountOut);

        // emit TokenBought(_tokenIn, _tokenOut, _amountIn, amountOut);
    }

    /**
     * @notice Simulates selling _tokenIn for _tokenOut using a constant product formula (x*y=k).
     * Includes a swap fee. This is essentially the same as buyToken but named for clarity.
     * @param _tokenIn The address of the token being sent into the DEX.
     * @param _tokenOut The address of the token being received from the DEX.
     * @param _amountIn The amount of _tokenIn to swap.
     * @return amountOut The amount of _tokenOut received.
     */
    function sellToken(address _tokenIn, address _tokenOut, uint256 _amountIn) external view returns (uint256 amountOut) {
        // This function's logic is identical to buyToken for a simple AMM,
        // as swaps are symmetrical. Renamed for conceptual clarity in arbitrage.
        amountOut = buyToken(_tokenIn, _tokenOut, _amountIn);
    }

    /**
     * @notice Gets the current price of _tokenA in terms of _tokenB.
     * (How many _tokenB you get for 1 _tokenA)
     * @param _tokenA The address of the input token.
     * @param _tokenB The address of the output token.
     * @return price The amount of _tokenB you would get for 1 unit of _tokenA.
     */
    function getPrice(address _tokenA, address _tokenB) external view returns (uint256 price) {
        require(_tokenA != _tokenB, "Dex: Cannot get price for same tokens");
        require((_tokenA == DAI_ADDRESS && _tokenB == USDC_ADDRESS) || (_tokenA == USDC_ADDRESS && _tokenB == DAI_ADDRESS), "Dex: Unsupported token pair");

        uint256 reserveA = IERC20(_tokenA).balanceOf(address(this));
        uint256 reserveB = IERC20(_tokenB).balanceOf(address(this));

        require(reserveA > 0 && reserveB > 0, "Dex: Insufficient liquidity for price calculation");

        // Price = reserveB / reserveA (for 1 unit of tokenA)
        // To handle decimals and get a meaningful price, we need to scale.
        // For simplicity, let's assume 18 decimals for both tokens for now.
        // If tokens have different decimals, you'd need to adjust.
        price = (reserveB * (10**18)) / reserveA; // Price of 1 tokenA in tokenB units (scaled)
    }


    // Function to get the balance of a specific token held by this DEX contract
    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    // Function to withdraw tokens from the DEX (only callable by owner)
    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    // Modifier to restrict function calls to the contract owner
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    // Fallback function to receive Ether (if any ETH is sent to the contract)
    receive() external payable {}
}