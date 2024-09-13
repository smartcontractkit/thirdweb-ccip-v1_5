// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {BurnMintTokenPool, TokenPool} from "@chainlink/contracts-ccip/src/v0.8/ccip/pools/BurnMintTokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePoolScript is Script {
    function run(
        address localChain_burnMintTokenPoolAddress,
        uint64 remoteChain_chainSelector,
        address remoteChain_burnMintTokenPoolAddress,
        address remoteChain_tokenAddress
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BurnMintTokenPool localChain_burnMintTokenPool = BurnMintTokenPool(localChain_burnMintTokenPoolAddress);

        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChain_chainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remoteChain_burnMintTokenPoolAddress),
            remoteTokenAddress: abi.encode(remoteChain_tokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: true, capacity: 100_000, rate: 167}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: true, capacity: 100_000, rate: 167})
        });

        localChain_burnMintTokenPool.applyChainUpdates(chains);

        vm.stopBroadcast();
    }
}
