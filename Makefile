# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update

# Deployment helpers
deploy-allowlist-hook: 
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) TOKEN_A=$(TOKEN_A) TOKEN_B=$(TOKEN_B) \
	forge script script/deploy/DeployAllowlistHook.s.sol:DeployAllowlistHook --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

deploy-allowlist-hook-and-pool: 
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) TOKEN_A=$(TOKEN_A) TOKEN_B=$(TOKEN_B) \
	forge script script/deploy/DeployAllowlistHookAndPool.s.sol:DeployAllowlistHookAndPool --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

deploy-tick-range-hook:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) TOKEN_A=$(TOKEN_A) TOKEN_B=$(TOKEN_B) \
	forge script script/deploy/DeployTickRangeHook.s.sol:DeployTickRangeHook --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

deploy-tick-range-hook-and-pool:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) TOKEN_A=$(TOKEN_A) TOKEN_B=$(TOKEN_B) \
	forge script script/deploy/DeployTickRangeHookAndPool.s.sol:DeployTickRangeHookAndPool --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v \
	--verify

## Local
deploy-wm-usdc-allowlist-hook-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-wm-usdc-allowlist-hook-local: TOKEN_A="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
deploy-wm-usdc-allowlist-hook-local: TOKEN_B="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-wm-usdc-allowlist-hook-local: deploy-allowlist-hook

deploy-wm-usdc-allowlist-hook-and-pool-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-wm-usdc-allowlist-hook-and-pool-local: TOKEN_A="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
deploy-wm-usdc-allowlist-hook-and-pool-local: TOKEN_B="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-wm-usdc-allowlist-hook-and-pool-local: deploy-allowlist-hook-and-pool

deploy-usdc-musd-tick-range-hook-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-usdc-musd-tick-range-hook-local: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-usdc-musd-tick-range-hook-local: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
deploy-usdc-musd-tick-range-hook-local: deploy-tick-range-hook

deploy-usdc-musd-tick-range-hook-and-pool-local: RPC_URL=$(LOCALHOST_RPC_URL)
deploy-usdc-musd-tick-range-hook-and-pool-local: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-usdc-musd-tick-range-hook-and-pool-local: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
deploy-usdc-musd-tick-range-hook-and-pool-local: deploy-tick-range-hook-and-pool

## Ethereum Mainnet
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: RPC_URL=$(MAINNET_RPC_URL)
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TOKEN_A="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TOKEN_B="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: deploy-allowlist-hook-and-pool

deploy-usdc-musd-tick-range-hook-and-pool-ethereum: RPC_URL=$(MAINNET_RPC_URL)
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: deploy-tick-range-hook-and-pool

# Uniswap Pool Management helpers
create-liquidity-position:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) UNISWAP_HOOK=$(UNISWAP_HOOK) TOKEN_A=$(TOKEN_A) TOKEN_B=$(TOKEN_B) \
	forge script script/dev/CreateLiquidityPosition.s.sol:CreateLiquidityPosition --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v

## Local
create-wm-usdc-liquidity-position-local: RPC_URL=$(LOCALHOST_RPC_URL)
create-wm-usdc-liquidity-position-local: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
create-wm-usdc-liquidity-position-local: TOKEN_A="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
create-wm-usdc-liquidity-position-local: TOKEN_B="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-wm-usdc-liquidity-position-local: create-liquidity-position

create-usdc-musd-liquidity-position-local: RPC_URL=$(LOCALHOST_RPC_URL)
create-usdc-musd-liquidity-position-local: UNISWAP_HOOK="0xB16B423BaFb487A3CdF1b493B55eb00066910800" # Tick Range Hook
create-usdc-musd-liquidity-position-local: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-usdc-musd-liquidity-position-local: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
create-usdc-musd-liquidity-position-local: create-liquidity-position

## Ethereum Mainnet
create-wm-usdc-liquidity-position-ethereum: RPC_URL=$(MAINNET_RPC_URL)
create-wm-usdc-liquidity-position-ethereum: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0"
create-wm-usdc-liquidity-position-ethereum: TOKEN_A="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
create-wm-usdc-liquidity-position-ethereum: TOKEN_B="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-wm-usdc-liquidity-position-ethereum: create-liquidity-position

create-usdc-musd-liquidity-position-ethereum: RPC_URL=$(MAINNET_RPC_URL)
create-usdc-musd-liquidity-position-ethereum: UNISWAP_HOOK= # TODO
create-usdc-musd-liquidity-position-ethereum: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
create-usdc-musd-liquidity-position-ethereum: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
create-usdc-musd-liquidity-position-ethereum: create-liquidity-position

swap:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) UNISWAP_HOOK=$(UNISWAP_HOOK) TOKEN_A=$(TOKEN_A) TOKEN_B=$(TOKEN_B) \
	forge script script/dev/Swap.s.sol:Swap --rpc-url $(RPC_URL) \
	--skip test --broadcast --slow --non-interactive -v

## Local
swap-usdc-to-wm-local: RPC_URL=$(LOCALHOST_RPC_URL)
swap-usdc-to-wm-local: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
swap-usdc-to-wm-local: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-wm-local: TOKEN_B="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
swap-usdc-to-wm-local: WITH_PREDICATE_MESSAGE=true
swap-usdc-to-wm-local: swap

swap-usdc-to-musd-local: RPC_URL=$(LOCALHOST_RPC_URL)
swap-usdc-to-musd-local: UNISWAP_HOOK="0xB16B423BaFb487A3CdF1b493B55eb00066910800" # Tick Range Hook
swap-usdc-to-musd-local: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-musd-local: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
swap-usdc-to-musd-local: WITH_PREDICATE_MESSAGE=false
swap-usdc-to-musd-local: swap

## Ethereum Mainnet
swap-usdc-to-wm-ethereum: RPC_URL=$(MAINNET_RPC_URL)
swap-usdc-to-wm-ethereum: UNISWAP_HOOK="0xAf53Cb78035A8E0acCe38441793E2648B15B88a0" # Allowlist Hook
swap-usdc-to-wm-ethereum: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-wm-ethereum: TOKEN_B="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
swap-usdc-to-wm-ethereum: WITH_PREDICATE_MESSAGE=true
swap-usdc-to-wm-ethereum: swap

swap-usdc-to-musd-ethereum: RPC_URL=$(MAINNET_RPC_URL)
swap-usdc-to-musd-ethereum: UNISWAP_HOOK= # TODO
swap-usdc-to-musd-ethereum: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
swap-usdc-to-musd-ethereum: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
swap-usdc-to-musd-ethereum: WITH_PREDICATE_MESSAGE=false
swap-usdc-to-musd-ethereum: swap

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
