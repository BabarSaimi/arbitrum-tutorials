// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@arbitrum/token-bridge-contracts/contracts/tokenbridge/arbitrum/gateway/L2ArbitrumGateway.sol";
import "@arbitrum/token-bridge-contracts/contracts/tokenbridge/libraries/gateway/ICustomGateway.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Example implementation of a custom gateway to be deployed on L2
 * @dev Inheritance of Ownable is optional. In this case we use it to call the function setTokenBridgeInformation
 * and simplify the test
 */
contract L2CustomGateway is L2ArbitrumGateway, ICustomGateway, Ownable {
    // Exit number (used for tradeable exits)
    uint256 public exitNum;

    // Token bridge state variables
    address public l1CustomToken;
    address public l2CustomToken;
    address public l1Gateway;
    address public router;
    bool private tokenBridgeInformationSet = false;

    // Custom functionality
    bool public allowsWithdrawals = false;

    /**
     * Contract constructor, sets the L2 router to be used in the contract's functions
     * @param router_ L2GatewayRouter address
     */
    constructor(address router_) {
        router = router_;
    }

    /**
     * Sets the information needed to use the gateway. To simplify the process of testing, this function can be called once
     * by the owner of the contract to set these addresses.
     * @param l1CustomToken_ address of the custom token on L1
     * @param l2CustomToken_ address of the custom token on L2
     * @param l1Gateway_ address of the counterpart gateway (on L1)
     */
    function setTokenBridgeInformation(
        address l1CustomToken_,
        address l2CustomToken_,
        address l1Gateway_
    ) public onlyOwner {
        require(tokenBridgeInformationSet == false, "Token bridge information already set");
        tokenBridgeInformationSet = true;
        l1CustomToken = l1CustomToken_;
        l2CustomToken = l2CustomToken_;
        l1Gateway = l1Gateway_;

        // Initializing ArbitrumGateway
        L2ArbitrumGateway._initialize(l1Gateway, router);

        // Allows deposits after the information has been set
        allowsWithdrawals = true;
    }

    /// @dev See {ICustomGateway-outboundTransfer}
    function outboundTransfer(
        address l1Token,
        address to,
        uint256 amount,
        bytes calldata data
    ) public payable returns (bytes memory) {
        return outboundTransfer(l1Token, to, amount, 0, 0, data);
    }

    /// @dev See {ICustomGateway-outboundTransfer}
    function outboundTransfer(
        address l1Token,
        address to,
        uint256 amount,
        uint256, /* _maxGas */
        uint256, /* _gasPriceBid */
        bytes calldata data
    ) public payable override returns (bytes memory res) {
        // Only execute if deposits are allowed
        require(allowsWithdrawals == true, "Withdrawals are currently disabled");

        // Only allow the custom token to be bridged through this gateway
        require(l1Token == l1CustomToken, "Token is not allowed through this gateway");

        return
            super.outboundTransfer(
                l1Token,
                to,
                amount,
                0,
                0,
                data
            );
    }

    /// @dev See {ICustomGateway-finalizeInboundTransfer}
    function finalizeInboundTransfer(
        address l1Token,
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) public payable override {
        // Only allow the custom token to be bridged through this gateway
        require(l1Token == l1CustomToken, "Token is not allowed through this gateway");

        // the superclass checks onlyCounterpartGateway
        super.finalizeInboundTransfer(l1Token, from, to, amount, data);
    }

    /// @dev See {ICustomGateway-calculateL2TokenAddress}
    function calculateL2TokenAddress(address) public view override returns (address) {
        return l2CustomToken;
    }

    /// @dev See {ICustomGateway-counterpartGateway}
    function counterpartGateway() public view override returns (address) {
        return l1Gateway;
    }

    // --------------------
    // Custom methods
    // --------------------
    /**
     * Disables the ability to deposit funds
     */
    function disableWithdrawals() public onlyOwner {
        allowsWithdrawals = false;
    }

    /**
     * Enables the ability to deposit funds
     */
    function enableWithdrawals() public onlyOwner {
        require(tokenBridgeInformationSet == true, "Token bridge information has not been set yet");
        allowsWithdrawals = true;
    }
}
