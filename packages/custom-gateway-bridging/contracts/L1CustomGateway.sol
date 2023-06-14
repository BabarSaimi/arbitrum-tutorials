// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@arbitrum/token-bridge-contracts/contracts/tokenbridge/ethereum/gateway/L1ArbitrumExtendedGateway.sol";
import "@arbitrum/token-bridge-contracts/contracts/tokenbridge/libraries/gateway/ICustomGateway.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Example implementation of a custom gateway to be deployed on L1
 * @dev Inheritance of Ownable is optional. In this case we use it to call the function setTokenBridgeInformation
 * and simplify the test
 */
contract L1CustomGateway is L1ArbitrumExtendedGateway, ICustomGateway, Ownable {
    
    // Token bridge state variables
    address public l1CustomToken;
    address public l2CustomToken;
    address public l2Gateway;
    address public inbox;
    address public router;
    bool private tokenBridgeInformationSet = false;

    // Custom functionality
    bool public allowsDeposits = false;

    /**
     * Contract constructor, sets the L1 router to be used in the contract's functions and calls L1CrosschainMessenger's constructor
     * @param router_ L1GatewayRouter address
     * @param inbox_ Inbox address
     */
    constructor(
        address router_,
        address inbox_
    ) {
        router = router_;
        inbox = inbox_;
    }

    /**
     * Sets the information needed to use the gateway. To simplify the process of testing, this function can be called once
     * by the owner of the contract to set these addresses.
     * @param l1CustomToken_ address of the custom token on L1
     * @param l2CustomToken_ address of the custom token on L2
     * @param l2Gateway_ address of the counterpart gateway (on L2)
     */
    function setTokenBridgeInformation(
        address l1CustomToken_,
        address l2CustomToken_,
        address l2Gateway_
    ) public onlyOwner {
        require(tokenBridgeInformationSet == false, "Token bridge information already set");
        tokenBridgeInformationSet = true;
        l1CustomToken = l1CustomToken_;
        l2CustomToken = l2CustomToken_;
        l2Gateway = l2Gateway_;

        // Initializing ArbitrumGateway
        L1ArbitrumGateway._initialize(l2Gateway, router, inbox);

        // Allows deposits after the information has been set
        allowsDeposits = true;
    }

    /// @dev See {ICustomGateway-outboundTransfer}
    function outboundTransfer(
        address l1Token,
        address to,
        uint256 amount,
        uint256 maxGas,
        uint256 gasPriceBid,
        bytes calldata data
    ) public payable override returns (bytes memory) {
        return outboundTransferCustomRefund(l1Token, to, to, amount, maxGas, gasPriceBid, data);
    }

    /// @dev See {IL1CustomGateway-outboundTransferCustomRefund}
    function outboundTransferCustomRefund(
        address l1Token,
        address refundTo,
        address to,
        uint256 amount,
        uint256 maxGas,
        uint256 gasPriceBid,
        bytes calldata data
    ) public payable override nonReentrant() returns (bytes memory res) {
        // Only execute if deposits are allowed
        require(allowsDeposits == true, "Deposits are currently disabled");

        // Only allow the custom token to be bridged through this gateway
        require(l1Token == l1CustomToken, "Token is not allowed through this gateway");

        return
            super.outboundTransferCustomRefund(
                l1Token,
                refundTo,
                to,
                amount,
                maxGas,
                gasPriceBid,
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
    ) public payable override nonReentrant {
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
        return l2Gateway;
    }

    // --------------------
    // Custom methods
    // --------------------
    /**
     * Disables the ability to deposit funds
     */
    function disableDeposits() public onlyOwner {
        allowsDeposits = false;
    }

    /**
     * Enables the ability to deposit funds
     */
    function enableDeposits() public onlyOwner {
        require(tokenBridgeInformationSet == true, "Token bridge information has not been set yet");
        allowsDeposits = true;
    }
}
