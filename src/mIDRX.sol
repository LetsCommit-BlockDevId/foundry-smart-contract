// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title mIDRX
 * @dev Mock Indonesian Rupiah Token (IDRX) for demonstration purposes
 * @notice This is a mock token with public minting - NOT for production use
 */
contract mIDRX is ERC20 {
    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @dev Number of decimals for the token (matching typical stablecoin standards)
    uint8 private constant DECIMALS = 2;

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @dev Constructor that sets the token name and symbol. A permissionless token.
     */
    constructor() ERC20("Mock IDRX", "mIDRX") {}

    // ============================================================================
    // PUBLIC FUNCTIONS
    // ============================================================================

    /**
     * @dev Public mint function - allows anyone to mint tokens
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint (in wei, considering decimals)
     * @notice This is for demonstration only - production tokens should have access control
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @dev Returns the number of decimals used by the token
     * @return Number of decimals (6)
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
