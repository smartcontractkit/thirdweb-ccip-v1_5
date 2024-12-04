// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {BurnMintERC677} from "../src/BurnMintERC677.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {BurnMintTokenPool, TokenPool} from "@chainlink/contracts-ccip/src/v0.8/ccip/pools/BurnMintTokenPool.sol";
import {IBurnMintERC20} from "@chainlink/contracts-ccip/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";
import {RegistryModuleOwnerCustom} from
    "@chainlink/contracts-ccip/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IERC20} from
    "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract MyTokenTest is Test {
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    BurnMintERC677 public myTokenEthSepolia;
    BurnMintERC677 public myTokenArbitrumSepolia;

    uint256 ethSepoliaFork;
    uint256 arbitrumSepoliaFork;

    Register.NetworkDetails public ethSepoliaNetworkDetails;
    Register.NetworkDetails public arbitrumSepoliaNetworkDetails;

    address alice;

    function setUp() public {
        alice = makeAddr("alice");

        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        string memory ARBITRUM_SEPOLIA_RPC_URL = vm.envString("ARBITRUM_SEPOLIA_RPC_URL");
        ethSepoliaFork = vm.createSelectFork(ETHEREUM_SEPOLIA_RPC_URL);
        arbitrumSepoliaFork = vm.createFork(ARBITRUM_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        string memory name = "My Token Burn And Mint";
        string memory symbol = "MTBnM";
        uint8 decimals = 18;
        uint256 maxSupply = type(uint256).max;

        // Step 1) Deploy token on Ethereum Sepolia
        vm.startPrank(alice);
        myTokenEthSepolia = new BurnMintERC677(name, symbol, decimals, maxSupply);
        vm.stopPrank();

        // Step 2) Deploy token on Arbitrum Sepolia
        vm.selectFork(arbitrumSepoliaFork);

        vm.startPrank(alice);
        myTokenArbitrumSepolia = new BurnMintERC677(name, symbol, decimals, maxSupply);
        vm.stopPrank();
    }

    function test_supportNewCCIPToken() public {
        // Step 3) Deploy BurnMintTokenPool on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);
        ethSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        address[] memory allowlist = new address[](0);

        vm.startPrank(alice);
        uint8 localTokenDecimals = 18;
        BurnMintTokenPool burnMintTokenPoolEthSepolia = new BurnMintTokenPool(
            IBurnMintERC20(address(myTokenEthSepolia)),
            localTokenDecimals,
            allowlist,
            ethSepoliaNetworkDetails.rmnProxyAddress,
            ethSepoliaNetworkDetails.routerAddress
        );
        vm.stopPrank();

        // Step 4) Deploy BurnMintTokenPool on Arbitrum Sepolia
        vm.selectFork(arbitrumSepoliaFork);
        arbitrumSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        vm.startPrank(alice);
        BurnMintTokenPool burnMintTokenPoolArbitrumSepolia = new BurnMintTokenPool(
            IBurnMintERC20(address(myTokenArbitrumSepolia)),
            localTokenDecimals,
            allowlist,
            arbitrumSepoliaNetworkDetails.rmnProxyAddress,
            arbitrumSepoliaNetworkDetails.routerAddress
        );
        vm.stopPrank();

        // Step 5) Grant Mint and Burn roles to BurnMintTokenPool on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);

        vm.startPrank(alice);
        myTokenEthSepolia.grantMintAndBurnRoles(address(burnMintTokenPoolEthSepolia));
        vm.stopPrank();

        // Step 6) Grant Mint and Burn roles to BurnMintTokenPool on Arbitrum Sepolia
        vm.selectFork(arbitrumSepoliaFork);

        vm.startPrank(alice);
        myTokenArbitrumSepolia.grantMintAndBurnRoles(address(burnMintTokenPoolArbitrumSepolia));
        vm.stopPrank();

        // Step 7) Claim Admin role on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);

        RegistryModuleOwnerCustom registryModuleOwnerCustomEthSepolia =
            RegistryModuleOwnerCustom(ethSepoliaNetworkDetails.registryModuleOwnerCustomAddress);

        vm.startPrank(alice);
        registryModuleOwnerCustomEthSepolia.registerAdminViaOwner(address(myTokenEthSepolia));
        vm.stopPrank();

        // Step 8) Claim Admin role on Arbitrum Sepolia
        vm.selectFork(arbitrumSepoliaFork);

        RegistryModuleOwnerCustom registryModuleOwnerCustomArbitrumSepolia =
            RegistryModuleOwnerCustom(arbitrumSepoliaNetworkDetails.registryModuleOwnerCustomAddress);

        vm.startPrank(alice);
        registryModuleOwnerCustomArbitrumSepolia.registerAdminViaOwner(address(myTokenArbitrumSepolia));
        vm.stopPrank();

        // Step 9) Accept Admin role on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);

        TokenAdminRegistry tokenAdminRegistryEthSepolia =
            TokenAdminRegistry(ethSepoliaNetworkDetails.tokenAdminRegistryAddress);

        vm.startPrank(alice);
        tokenAdminRegistryEthSepolia.acceptAdminRole(address(myTokenEthSepolia));
        vm.stopPrank();

        // Step 10) Accept Admin role on Arbitrum Sepolia
        vm.selectFork(arbitrumSepoliaFork);

        TokenAdminRegistry tokenAdminRegistryArbitrumSepolia =
            TokenAdminRegistry(arbitrumSepoliaNetworkDetails.tokenAdminRegistryAddress);

        vm.startPrank(alice);
        tokenAdminRegistryArbitrumSepolia.acceptAdminRole(address(myTokenArbitrumSepolia));
        vm.stopPrank();

        // Step 11) Link token to pool on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);

        vm.startPrank(alice);
        tokenAdminRegistryEthSepolia.setPool(address(myTokenEthSepolia), address(burnMintTokenPoolEthSepolia));
        vm.stopPrank();

        // Step 12) Link token to pool on Arbitrum Sepolia
        vm.selectFork(arbitrumSepoliaFork);

        vm.startPrank(alice);
        tokenAdminRegistryArbitrumSepolia.setPool(
            address(myTokenArbitrumSepolia), address(burnMintTokenPoolArbitrumSepolia)
        );
        vm.stopPrank();

        // Step 13) Configure Token Pool on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);

        vm.startPrank(alice);
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddressesEthSepolia = new bytes[](1);
        remotePoolAddressesEthSepolia[0] = abi.encode(address(burnMintTokenPoolArbitrumSepolia));
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: arbitrumSepoliaNetworkDetails.chainSelector,
            remotePoolAddresses: remotePoolAddressesEthSepolia,
            remoteTokenAddress: abi.encode(address(myTokenArbitrumSepolia)),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: true, capacity: 100_000, rate: 167}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: true, capacity: 100_000, rate: 167})
        });
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
        burnMintTokenPoolEthSepolia.applyChainUpdates(remoteChainSelectorsToRemove, chains);
        vm.stopPrank();

        // Step 14) Configure Token Pool on Arbitrum Sepolia
        vm.selectFork(arbitrumSepoliaFork);

        vm.startPrank(alice);
        chains = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddressesArbitrumSepolia = new bytes[](1);
        remotePoolAddressesArbitrumSepolia[0] = abi.encode(address(burnMintTokenPoolEthSepolia));
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: ethSepoliaNetworkDetails.chainSelector,
            remotePoolAddresses: remotePoolAddressesArbitrumSepolia,
            remoteTokenAddress: abi.encode(address(myTokenEthSepolia)),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: true, capacity: 100_000, rate: 167}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: true, capacity: 100_000, rate: 167})
        });
        burnMintTokenPoolArbitrumSepolia.applyChainUpdates(remoteChainSelectorsToRemove, chains);
        vm.stopPrank();

        // Step 15) Mint tokens on Ethereum Sepolia and transfer them to Arbitrum Sepolia
        vm.selectFork(ethSepoliaFork);

        address linkSepolia = ethSepoliaNetworkDetails.linkAddress;
        ccipLocalSimulatorFork.requestLinkFromFaucet(address(alice), 20 ether);

        uint256 amountToSend = 100;
        Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount =
            Client.EVMTokenAmount({token: address(myTokenEthSepolia), amount: amountToSend});
        tokenToSendDetails[0] = tokenAmount;

        vm.startPrank(alice);
        myTokenEthSepolia.grantMintRole(address(alice));
        myTokenEthSepolia.mint(address(alice), amountToSend);

        myTokenEthSepolia.approve(ethSepoliaNetworkDetails.routerAddress, amountToSend);
        IERC20(linkSepolia).approve(ethSepoliaNetworkDetails.routerAddress, 20 ether);

        uint256 balanceOfAliceBeforeEthSepolia = myTokenEthSepolia.balanceOf(alice);

        IRouterClient routerEthSepolia = IRouterClient(ethSepoliaNetworkDetails.routerAddress);
        routerEthSepolia.ccipSend(
            arbitrumSepoliaNetworkDetails.chainSelector,
            Client.EVM2AnyMessage({
                receiver: abi.encode(address(alice)),
                data: "",
                tokenAmounts: tokenToSendDetails,
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})),
                feeToken: linkSepolia
            })
        );

        uint256 balanceOfAliceAfterEthSepolia = myTokenEthSepolia.balanceOf(alice);
        vm.stopPrank();

        assertEq(balanceOfAliceAfterEthSepolia, balanceOfAliceBeforeEthSepolia - amountToSend);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumSepoliaFork);

        uint256 balanceOfAliceAfterArbitrumSepolia = myTokenArbitrumSepolia.balanceOf(alice);
        assertEq(balanceOfAliceAfterArbitrumSepolia, amountToSend);
    }
}
