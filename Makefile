# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update

# Deployment helpers
deploy-allowlist-hook: 
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	forge script script/deploy/DeployAllowlistHook.s.sol:DeployAllowlistHook --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

deploy-allowlist-hook-and-pool: 
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	forge script script/deploy/DeployAllowlistHookAndPool.s.sol:DeployAllowlistHookAndPool --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

deploy-tick-range-hook:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	forge script script/deploy/DeployTickRangeHook.s.sol:DeployTickRangeHook --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

deploy-tick-range-hook-and-pool:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	forge script script/deploy/DeployTickRangeHookAndPool.s.sol:DeployTickRangeHookAndPool --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

## Local
deploy-wm-usdc-allowlist-hook-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-wm-usdc-allowlist-hook-local: TOKEN_0="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
deploy-wm-usdc-allowlist-hook-local: TOKEN_1="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-wm-usdc-allowlist-hook-local: TICK_LOWER_BOUND=-1
deploy-wm-usdc-allowlist-hook-local: TICK_UPPER_BOUND=1
deploy-wm-usdc-allowlist-hook-local: deploy-allowlist-hook

deploy-wm-usdc-allowlist-hook-and-pool-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-wm-usdc-allowlist-hook-and-pool-local: TOKEN_0="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
deploy-wm-usdc-allowlist-hook-and-pool-local: TOKEN_1="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-wm-usdc-allowlist-hook-and-pool-local: TICK_LOWER_BOUND=-1
deploy-wm-usdc-allowlist-hook-and-pool-local: TICK_UPPER_BOUND=1
deploy-wm-usdc-allowlist-hook-and-pool-local: deploy-allowlist-hook-and-pool

deploy-usdc-musd-tick-range-hook-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-usdc-musd-tick-range-hook-local: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-usdc-musd-tick-range-hook-local: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
deploy-usdc-musd-tick-range-hook-local: TICK_LOWER_BOUND=0
deploy-usdc-musd-tick-range-hook-local: TICK_UPPER_BOUND=1
deploy-usdc-musd-tick-range-hook-local: deploy-tick-range-hook

deploy-usdc-musd-tick-range-hook-and-pool-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-usdc-musd-tick-range-hook-and-pool-local: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-usdc-musd-tick-range-hook-and-pool-local: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
deploy-usdc-musd-tick-range-hook-and-pool-local: TICK_LOWER_BOUND=0
deploy-usdc-musd-tick-range-hook-and-pool-local: TICK_UPPER_BOUND=1
deploy-usdc-musd-tick-range-hook-and-pool-local: deploy-tick-range-hook-and-pool

## Ethereum Mainnet
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: RPC_URL=$(MAINNET_RPC_URL)
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TOKEN_0="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TOKEN_1="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TICK_LOWER_BOUND=-1
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TICK_UPPER_BOUND=1
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: deploy-allowlist-hook-and-pool

deploy-usdc-musd-tick-range-hook-and-pool-ethereum: RPC_URL=$(MAINNET_RPC_URL)
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TICK_LOWER_BOUND=0
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TICK_UPPER_BOUND=1
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: deploy-tick-range-hook-and-pool

# Uniswap Pool Management helpers

# Logging helpers
print-pool-state:
	UNISWAP_HOOK=$(UNISWAP_HOOK) TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	forge script script/dev/PrintPoolState.s.sol:PrintPoolState --rpc-url $(RPC_URL) \
	--skip test -v

## Local
print-wm-usdc-pool-state-local: RPC_URL=$(LOCALHOST_RPC_URL)
print-wm-usdc-pool-state-local: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
print-wm-usdc-pool-state-local: TOKEN_0="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
print-wm-usdc-pool-state-local: TOKEN_1="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
print-wm-usdc-pool-state-local: TICK_LOWER_BOUND=-1
print-wm-usdc-pool-state-local: TICK_UPPER_BOUND=1
print-wm-usdc-pool-state-local: print-pool-state

print-usdc-musd-pool-state-local: RPC_URL=$(LOCALHOST_RPC_URL)
print-usdc-musd-pool-state-local: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
print-usdc-musd-pool-state-local: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
print-usdc-musd-pool-state-local: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
print-usdc-musd-pool-state-local: TICK_LOWER_BOUND=0
print-usdc-musd-pool-state-local: TICK_UPPER_BOUND=1
print-usdc-musd-pool-state-local: print-pool-state

## Ethereum Mainnet
print-wm-usdc-pool-state-ethereum: RPC_URL=$(MAINNET_RPC_URL)
print-wm-usdc-pool-state-ethereum: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
print-wm-usdc-pool-state-ethereum: TOKEN_0="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
print-wm-usdc-pool-state-ethereum: TOKEN_1="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
print-wm-usdc-pool-state-ethereum: TICK_LOWER_BOUND=-1
print-wm-usdc-pool-state-ethereum: TICK_UPPER_BOUND=1
print-wm-usdc-pool-state-ethereum: print-pool-state

print-usdc-musd-pool-state-ethereum: RPC_URL=$(MAINNET_RPC_URL)
print-usdc-musd-pool-state-ethereum: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
print-usdc-musd-pool-state-ethereum: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
print-usdc-musd-pool-state-ethereum: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
print-usdc-musd-pool-state-ethereum: TICK_LOWER_BOUND=0
print-usdc-musd-pool-state-ethereum: TICK_UPPER_BOUND=1
print-usdc-musd-pool-state-ethereum: print-pool-state

print-position-state:
	TOKEN_ID=$(TOKEN_ID) \
	forge script script/dev/PrintPositionState.s.sol:PrintPositionState --rpc-url $(RPC_URL) \
	--skip test -v

## Local
print-wm-usdc-position-state-local: RPC_URL=$(LOCALHOST_RPC_URL)
print-wm-usdc-position-state-local: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
print-wm-usdc-position-state-local: print-position-state

print-usdc-musd-position-state-local: RPC_URL=$(LOCALHOST_RPC_URL)
print-usdc-musd-position-state-local: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
print-usdc-musd-position-state-local: print-position-state

## Ethereum Mainnet
print-wm-usdc-position-state-ethereum: RPC_URL=$(MAINNET_RPC_URL)
print-wm-usdc-position-state-ethereum: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
print-wm-usdc-position-state-ethereum: print-position-state

print-usdc-musd-position-state-ethereum: RPC_URL=$(MAINNET_RPC_URL)
print-usdc-musd-position-state-ethereum: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
print-usdc-musd-position-state-ethereum: print-position-state

# Liquidity Position helpers
create-liquidity-position:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	UNISWAP_HOOK=$(UNISWAP_HOOK) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) AMOUNT_0=$(AMOUNT_0) AMOUNT_1=$(AMOUNT_1) \
	forge script script/dev/CreateLiquidityPosition.s.sol:CreateLiquidityPosition --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v

## Local
create-wm-usdc-liquidity-position-local: RPC_URL=$(LOCALHOST_RPC_URL)
create-wm-usdc-liquidity-position-local: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
create-wm-usdc-liquidity-position-local: TOKEN_0="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
create-wm-usdc-liquidity-position-local: TOKEN_1="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-wm-usdc-liquidity-position-local: TICK_LOWER_BOUND=-1
create-wm-usdc-liquidity-position-local: TICK_UPPER_BOUND=1
create-wm-usdc-liquidity-position-local: create-liquidity-position

create-usdc-musd-liquidity-position-local: RPC_URL=$(LOCALHOST_RPC_URL)
create-usdc-musd-liquidity-position-local: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
create-usdc-musd-liquidity-position-local: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-usdc-musd-liquidity-position-local: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
create-usdc-musd-liquidity-position-local: TICK_LOWER_BOUND=0
create-usdc-musd-liquidity-position-local: TICK_UPPER_BOUND=1
create-usdc-musd-liquidity-position-local: create-liquidity-position

## Ethereum Mainnet
create-wm-usdc-liquidity-position-ethereum: RPC_URL=$(MAINNET_RPC_URL)
create-wm-usdc-liquidity-position-ethereum: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
create-wm-usdc-liquidity-position-ethereum: TOKEN_0="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
create-wm-usdc-liquidity-position-ethereum: TOKEN_1="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-wm-usdc-liquidity-position-ethereum: TICK_LOWER_BOUND=-1
create-wm-usdc-liquidity-position-ethereum: TICK_UPPER_BOUND=1
create-wm-usdc-liquidity-position-ethereum: create-liquidity-position

create-usdc-musd-liquidity-position-ethereum: RPC_URL=$(MAINNET_RPC_URL)
create-usdc-musd-liquidity-position-ethereum: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
create-usdc-musd-liquidity-position-ethereum: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-usdc-musd-liquidity-position-ethereum: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
create-usdc-musd-liquidity-position-ethereum: TICK_LOWER_BOUND=0
create-usdc-musd-liquidity-position-ethereum: TICK_UPPER_BOUND=1
create-usdc-musd-liquidity-position-ethereum: create-liquidity-position

create-liquidity-position-fireblocks:
	FOUNDRY_PROFILE=production  \
	FIREBLOCKS_API_KEY=$(FIREBLOCKS_API_KEY) FIREBLOCKS_API_PRIVATE_KEY_PATH=./fireblocks/api_private.key \
	FIREBLOCKS_SENDER=$(FIREBLOCKS_SENDER) \
	UNISWAP_HOOK=$(UNISWAP_HOOK) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) AMOUNT_0=$(AMOUNT_0) AMOUNT_1=$(AMOUNT_1) \
	fireblocks-json-rpc --vaultAccountIds [$(FIREBLOCKS_VAULT_ACCOUNT_ID)] --http --rpcUrl $(RPC_URL) -- \
	forge script script/dev/CreateLiquidityPosition.s.sol:CreateLiquidityPosition --rpc-url {} \
	--skip test --sender $(FIREBLOCKS_SENDER)  --broadcast --slow --non-interactive --unlocked -v

create-usdc-musd-liquidity-position-ethereum-fireblocks: RPC_URL=$(MAINNET_RPC_URL)
create-usdc-musd-liquidity-position-ethereum-fireblocks: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
create-usdc-musd-liquidity-position-ethereum-fireblocks: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-usdc-musd-liquidity-position-ethereum-fireblocks: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
create-usdc-musd-liquidity-position-ethereum-fireblocks: AMOUNT_0=2000000 # 2 USDC (6 decimals)
create-usdc-musd-liquidity-position-ethereum-fireblocks: AMOUNT_1=2000000 # 2 MUSD (6 decimals)
create-usdc-musd-liquidity-position-ethereum-fireblocks: TICK_LOWER_BOUND=0
create-usdc-musd-liquidity-position-ethereum-fireblocks: TICK_UPPER_BOUND=1
create-usdc-musd-liquidity-position-ethereum-fireblocks: create-liquidity-position-fireblocks

modify-liquidity-position:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	TOKEN_ID=$(TOKEN_ID) DECREASE_LIQUIDITY=$(DECREASE_LIQUIDITY) \
	AMOUNT_0=$(AMOUNT_0) AMOUNT_1=$(AMOUNT_1) \
	forge script script/dev/ModifyLiquidityPosition.s.sol:ModifyLiquidityPosition --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v

## Local
increase-usdc-musd-liquidity-position-local: RPC_URL=$(LOCALHOST_RPC_URL)
increase-usdc-musd-liquidity-position-local: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
increase-usdc-musd-liquidity-position-local: DECREASE_LIQUIDITY=false
increase-usdc-musd-liquidity-position-local: modify-liquidity-position

decrease-usdc-musd-liquidity-position-local: RPC_URL=$(LOCALHOST_RPC_URL)
decrease-usdc-musd-liquidity-position-local: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
decrease-usdc-musd-liquidity-position-local: DECREASE_LIQUIDITY=true
decrease-usdc-musd-liquidity-position-local: modify-liquidity-position

## Ethereum Mainnet
increase-usdc-musd-liquidity-position-ethereum: RPC_URL=$(MAINNET_RPC_URL)
increase-usdc-musd-liquidity-position-ethereum: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
increase-usdc-musd-liquidity-position-ethereum: DECREASE_LIQUIDITY=false
increase-usdc-musd-liquidity-position-ethereum: modify-liquidity-position

decrease-usdc-musd-liquidity-position-ethereum: RPC_URL=$(MAINNET_RPC_URL)
decrease-usdc-musd-liquidity-position-ethereum: TOKEN_ID=$(LP_POSITION_ID) # LP Position NFT ID
decrease-usdc-musd-liquidity-position-ethereum: DECREASE_LIQUIDITY=true
decrease-usdc-musd-liquidity-position-ethereum: modify-liquidity-position

swap:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	UNISWAP_HOOK=$(UNISWAP_HOOK) WITH_PREDICATE_MESSAGE=$(WITH_PREDICATE_MESSAGE) SLIPPAGE=$(SLIPPAGE) ZERO_FOR_ONE=$(ZERO_FOR_ONE) \
	TOKEN_0=$(TOKEN_0) TOKEN_1=$(TOKEN_1) TICK_LOWER_BOUND=$(TICK_LOWER_BOUND) TICK_UPPER_BOUND=$(TICK_UPPER_BOUND) \
	forge script script/dev/Swap.s.sol:Swap --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v

## Local
swap-usdc-to-wm-local: RPC_URL=$(LOCALHOST_RPC_URL)
swap-usdc-to-wm-local: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
swap-usdc-to-wm-local: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-wm-local: TOKEN_1="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
swap-usdc-to-wm-local: TICK_LOWER_BOUND=-1
swap-usdc-to-wm-local: TICK_UPPER_BOUND=1
swap-usdc-to-wm-local: SLIPPAGE=1 # Slippage in BPS (0.01%)
swap-usdc-to-wm-local: ZERO_FOR_ONE=false
swap-usdc-to-wm-local: WITH_PREDICATE_MESSAGE=true
swap-usdc-to-wm-local: swap

swap-usdc-to-musd-local: RPC_URL=$(LOCALHOST_RPC_URL)
swap-usdc-to-musd-local: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
swap-usdc-to-musd-local: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-musd-local: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
swap-usdc-to-musd-local: TICK_LOWER_BOUND=0
swap-usdc-to-musd-local: TICK_UPPER_BOUND=1
swap-usdc-to-musd-local: SLIPPAGE=1 # Slippage in BPS (0.01%)
swap-usdc-to-musd-local: ZERO_FOR_ONE=true
swap-usdc-to-musd-local: WITH_PREDICATE_MESSAGE=false
swap-usdc-to-musd-local: swap

swap-musd-to-usdc-local: RPC_URL=$(LOCALHOST_RPC_URL)
swap-musd-to-usdc-local: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
swap-musd-to-usdc-local: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-musd-to-usdc-local: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
swap-musd-to-usdc-local: TICK_LOWER_BOUND=0
swap-musd-to-usdc-local: TICK_UPPER_BOUND=1
swap-musd-to-usdc-local: SLIPPAGE=1 # Slippage in BPS (0.01%)
swap-musd-to-usdc-local: ZERO_FOR_ONE=false
swap-musd-to-usdc-local: WITH_PREDICATE_MESSAGE=false
swap-musd-to-usdc-local: swap

## Ethereum Mainnet
swap-usdc-to-wm-ethereum: RPC_URL=$(MAINNET_RPC_URL)
swap-usdc-to-wm-ethereum: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
swap-usdc-to-wm-ethereum: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-wm-ethereum: TOKEN_1="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
swap-usdc-to-wm-ethereum: TICK_LOWER_BOUND=-1
swap-usdc-to-wm-ethereum: TICK_UPPER_BOUND=1
swap-usdc-to-wm-ethereum: SLIPPAGE=1 # Slippage in BPS (0.01%)
swap-usdc-to-wm-ethereum: ZERO_FOR_ONE=false
swap-usdc-to-wm-ethereum: WITH_PREDICATE_MESSAGE=true
swap-usdc-to-wm-ethereum: swap

swap-usdc-to-musd-ethereum: RPC_URL=$(MAINNET_RPC_URL)
swap-usdc-to-musd-ethereum: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
swap-usdc-to-musd-ethereum: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-musd-ethereum: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
swap-usdc-to-musd-ethereum: TICK_LOWER_BOUND=0
swap-usdc-to-musd-ethereum: TICK_UPPER_BOUND=1
swap-usdc-to-musd-ethereum: SLIPPAGE=1 # Slippage in BPS (0.01%)
swap-usdc-to-musd-ethereum: ZERO_FOR_ONE=true
swap-usdc-to-musd-ethereum: WITH_PREDICATE_MESSAGE=false
swap-usdc-to-musd-ethereum: swap

swap-musd-to-usdc-ethereum: RPC_URL=$(MAINNET_RPC_URL)
swap-musd-to-usdc-ethereum: UNISWAP_HOOK="0x0000000000000000000000000000000000000000" # Pool without hook
swap-musd-to-usdc-ethereum: TOKEN_0="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-musd-to-usdc-ethereum: TOKEN_1="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
swap-musd-to-usdc-ethereum: TICK_LOWER_BOUND=0
swap-musd-to-usdc-ethereum: TICK_UPPER_BOUND=1
swap-musd-to-usdc-ethereum: SLIPPAGE=1 # Slippage in BPS (0.01%)
swap-musd-to-usdc-ethereum: ZERO_FOR_ONE=false
swap-musd-to-usdc-ethereum: WITH_PREDICATE_MESSAGE=false
swap-musd-to-usdc-ethereum: swap

# Flashswaps Wrapped M to swap into UsualM
## Local
flashswap-local :; forge script script/dev/FlashSwap.s.sol:FlashSwap --rpc-url localhost --broadcast -vvv

## Ethereum Mainnet
flashswap-ethereum :; forge script script/dev/FlashSwap.s.sol:FlashSwap --rpc-url mainnet --broadcast -vvv

# Run slither
slither :; FOUNDRY_PROFILE=production forge build --build-info --skip '*/test/**' --skip '*/script/**' --force && slither --compile-force-framework foundry --ignore-compile --sarif results.sarif --config-file slither.config.json .

# Common tasks
profile ?=default

build:
	@./build.sh -p production

tests:
	@./test.sh -p $(profile)

fuzz:
	@./test.sh -t testFuzz -p $(profile)

integration:
	@./test.sh -d test/integration -p $(profile)

invariant:
	@./test.sh -d test/invariant -p $(profile)

coverage:
	FOUNDRY_PROFILE=$(profile) forge coverage --no-match-path "test/{deploy,fork}/**/*.t.sol" --report lcov && lcov --extract lcov.info -o lcov.info 'src/*' && genhtml lcov.info -o coverage

gas-report:
	FOUNDRY_PROFILE=$(profile) forge test --gas-report > gasreport.ansi

sizes:
	@./build.sh -p production -s

clean:
	forge clean && rm -rf ./abi && rm -rf ./bytecode && rm -rf ./types
