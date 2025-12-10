// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAaveV3Pool
 * @notice Interface for Aave V3 Pool operations
 */
interface IAaveV3Pool {
    /**
     * @notice Supplies an `amount` of underlying asset into the reserve
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode Code used to register the integrator originating the operation
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Borrows an `amount` of underlying asset from the reserve
     * @param asset The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param interestRateMode The interest rate mode: 1 for Stable, 2 for Variable
     * @param referralCode Code used to register the integrator originating the operation
     * @param onBehalfOf The address of the user who will receive the debt
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Repays a borrowed `amount` on a specific reserve
     * @param asset The address of the borrowed underlying asset
     * @param amount The amount to repay
     * @param interestRateMode The interest rate mode: 1 for Stable, 2 for Variable
     * @param onBehalfOf The address of the user who will get his debt reduced/removed
     * @return The final amount repaid
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve
     * @param asset The address of the underlying asset to withdraw
     * @param amount The amount to be withdrawn
     * @param to The address that will receive the underlying
     * @return The final amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @notice Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralBase Total collateral in base currency
     * @return totalDebtBase Total debt in base currency
     * @return availableBorrowsBase Available to borrow in base currency
     * @return currentLiquidationThreshold Liquidation threshold of the user
     * @return ltv Loan to Value of the user
     * @return healthFactor Current health factor of the user
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction
     * @param receiverAddress The address of the contract receiving the funds
     * @param assets The addresses of the assets being flash-borrowed
     * @param amounts The amounts of the assets being flash-borrowed
     * @param interestRateModes Types of the debt to open if the flash loan is not returned
     * @param onBehalfOf The address that will receive the debt in case of not returning the flash loan
     * @param params Variadic packed params to pass to the receiver as extra information
     * @param referralCode Code used to register the integrator originating the operation
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Returns the normalized income of the reserve
     * @param asset The address of the underlying asset
     * @return The reserve's normalized income
     */
    function getReserveNormalizedIncome(address asset) external view returns (uint256);
}

/**
 * @title IFlashLoanSimpleReceiver
 * @notice Interface for flash loan receiver
 */
interface IFlashLoanSimpleReceiver {
    /**
     * @notice Executes an operation after receiving the flash-borrowed asset
     * @param asset The address of the flash-borrowed asset
     * @param amount The amount of the flash-borrowed asset
     * @param premium The fee of the flash-borrowed asset
     * @param initiator The address of the flashloan initiator
     * @param params The byte-encoded params passed when initiating the flashloan
     * @return True if the execution of the operation succeeds, false otherwise
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
