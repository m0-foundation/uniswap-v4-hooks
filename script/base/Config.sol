// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

/// @notice Shared configuration between scripts
contract Config {
    struct DeployConfig {
        address poolManager;
        address posm;
        address swapRouter;
        address usdc;
        address wrappedM;
        uint24 fee;
        int24 tickLowerBound;
        int24 tickUpperBound;
        int24 tickSpacing;
    }

    error UnsupportedChain(uint256 chainId);

    // Swap Fee in bps
    uint24 constant SWAP_FEE = 100;

    int24 constant TICK_LOWER_BOUND = 0;
    int24 constant TICK_UPPER_BOUND = 1;
    int24 constant TICK_SPACING = 1;

    // Mainnet chain IDs
    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;
    uint256 constant OPTIMISM_CHAIN_ID = 10;
    uint256 constant UNICHAIN_CHAIN_ID = 130;

    // Testnet chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;
    uint256 constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

    // Same addresses across all chains
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant WRAPPED_M = address(address(0x437cc33344a0B27A429f795ff6B469C72698B291));

    // Mainnet contract addresses
    address constant POOL_MANAGER_ETHEREUM = address(0x000000000004444c5dc75cB358380D2e3dE08A90);
    address constant POOL_MANAGER_ARBITRUM = address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32);
    address constant POOL_MANAGER_OPTIMISM = address(0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3);
    address constant POOL_MANAGER_UNICHAIN = address(0x1F98400000000000000000000000000000000004);

    address constant POSM_ETHEREUM = address(0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e);
    address constant POSM_ARBITRUM = address(0xd88F38F930b7952f2DB2432Cb002E7abbF3dD869);
    address constant POSM_OPTIMISM = address(0x3C3Ea4B57a46241e54610e5f022E5c45859A1017);
    address constant POSM_UNICHAIN = address(0x4529A01c7A0410167c5740C487A8DE60232617bf);

    address constant SWAP_ROUTER_ETHEREUM = address(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af);
    address constant SWAP_ROUTER_ARBITRUM = address(0xA51afAFe0263b40EdaEf0Df8781eA9aa03E381a3);
    address constant SWAP_ROUTER_OPTIMISM = address(0x851116D9223fabED8E56C0E6b8Ad0c31d98B3507);
    address constant SWAP_ROUTER_UNICHAIN = address(0xEf740bf23aCaE26f6492B10de645D6B98dC8Eaf3);

    address constant USDC_ETHEREUM = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant USDC_ARBITRUM = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address constant USDC_OPTIMISM = address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    address constant USDC_UNICHAIN = address(0x078D782b760474a361dDA0AF3839290b0EF57AD6);

    // Testnet contract addresses
    address constant POOL_MANAGER_SEPOLIA = address(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543);
    address constant POOL_MANAGER_ARBITRUM_SEPOLIA = address(0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317);
    address constant POOL_MANAGER_UNICHAIN_SEPOLIA = address(0x00B036B58a818B1BC34d502D3fE730Db729e62AC);

    address constant POSM_SEPOLIA = address(0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4);
    address constant POSM_ARBITRUM_SEPOLIA = address(0xAc631556d3d4019C95769033B5E719dD77124BAc);
    address constant POSM_UNICHAIN_SEPOLIA = address(0xf969Aee60879C54bAAed9F3eD26147Db216Fd664);

    address constant SWAP_ROUTER_SEPOLIA = address(0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b);
    address constant SWAP_ROUTER_ARBITRUM_SEPOLIA = address(0xeFd1D4bD4cf1e86Da286BB4CB1B8BcED9C10BA47);
    address constant SWAP_ROUTER_UNICHAIN_SEPOLIA = address(0xf70536B3bcC1bD1a972dc186A2cf84cC6da6Be5D);

    address constant USDC_SEPOLIA = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
    address constant USDC_ARBITRUM_SEPOLIA = address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);
    address constant USDC_UNICHAIN_SEPOLIA = address(0x31d0220469e10c4E71834a79b1f276d740d3768F);

    function _getDeployConfig(uint256 chainId_) internal pure returns (DeployConfig memory) {
        // Mainnet configs
        if (chainId_ == ETHEREUM_CHAIN_ID)
            return
                DeployConfig({
                    poolManager: POOL_MANAGER_ETHEREUM,
                    posm: POSM_ETHEREUM,
                    swapRouter: SWAP_ROUTER_ETHEREUM,
                    usdc: USDC_ETHEREUM,
                    wrappedM: WRAPPED_M,
                    fee: SWAP_FEE,
                    tickLowerBound: TICK_LOWER_BOUND,
                    tickUpperBound: TICK_UPPER_BOUND,
                    tickSpacing: TICK_SPACING
                });

        if (chainId_ == ARBITRUM_CHAIN_ID)
            return
                DeployConfig({
                    poolManager: POOL_MANAGER_ARBITRUM,
                    posm: POSM_ARBITRUM,
                    swapRouter: SWAP_ROUTER_ARBITRUM,
                    usdc: USDC_ARBITRUM,
                    wrappedM: WRAPPED_M,
                    fee: SWAP_FEE,
                    tickLowerBound: TICK_LOWER_BOUND,
                    tickUpperBound: TICK_UPPER_BOUND,
                    tickSpacing: TICK_SPACING
                });

        if (chainId_ == OPTIMISM_CHAIN_ID)
            return
                DeployConfig({
                    poolManager: POOL_MANAGER_OPTIMISM,
                    posm: POSM_OPTIMISM,
                    swapRouter: SWAP_ROUTER_OPTIMISM,
                    usdc: USDC_OPTIMISM,
                    wrappedM: WRAPPED_M,
                    fee: SWAP_FEE,
                    tickLowerBound: TICK_LOWER_BOUND,
                    tickUpperBound: TICK_UPPER_BOUND,
                    tickSpacing: TICK_SPACING
                });

        if (chainId_ == UNICHAIN_CHAIN_ID)
            return
                DeployConfig({
                    poolManager: POOL_MANAGER_UNICHAIN,
                    posm: POSM_UNICHAIN,
                    swapRouter: SWAP_ROUTER_UNICHAIN,
                    usdc: USDC_UNICHAIN,
                    wrappedM: WRAPPED_M,
                    fee: SWAP_FEE,
                    tickLowerBound: TICK_LOWER_BOUND,
                    tickUpperBound: TICK_UPPER_BOUND,
                    tickSpacing: TICK_SPACING
                });

        // Testnet configs
        if (chainId_ == SEPOLIA_CHAIN_ID)
            return
                DeployConfig({
                    poolManager: POOL_MANAGER_SEPOLIA,
                    posm: POSM_SEPOLIA,
                    swapRouter: SWAP_ROUTER_SEPOLIA,
                    usdc: USDC_SEPOLIA,
                    wrappedM: WRAPPED_M,
                    fee: SWAP_FEE,
                    tickLowerBound: TICK_LOWER_BOUND,
                    tickUpperBound: TICK_UPPER_BOUND,
                    tickSpacing: TICK_SPACING
                });

        if (chainId_ == ARBITRUM_SEPOLIA_CHAIN_ID)
            return
                DeployConfig({
                    poolManager: POOL_MANAGER_ARBITRUM_SEPOLIA,
                    posm: POSM_ARBITRUM_SEPOLIA,
                    swapRouter: SWAP_ROUTER_ARBITRUM_SEPOLIA,
                    usdc: USDC_ARBITRUM_SEPOLIA,
                    wrappedM: WRAPPED_M,
                    fee: SWAP_FEE,
                    tickLowerBound: TICK_LOWER_BOUND,
                    tickUpperBound: TICK_UPPER_BOUND,
                    tickSpacing: TICK_SPACING
                });

        if (chainId_ == UNICHAIN_SEPOLIA_CHAIN_ID)
            return
                DeployConfig({
                    poolManager: POOL_MANAGER_UNICHAIN_SEPOLIA,
                    posm: POSM_UNICHAIN_SEPOLIA,
                    swapRouter: SWAP_ROUTER_UNICHAIN_SEPOLIA,
                    usdc: USDC_UNICHAIN_SEPOLIA,
                    wrappedM: WRAPPED_M,
                    fee: SWAP_FEE,
                    tickLowerBound: TICK_LOWER_BOUND,
                    tickUpperBound: TICK_UPPER_BOUND,
                    tickSpacing: TICK_SPACING
                });

        revert UnsupportedChain(chainId_);
    }
}
