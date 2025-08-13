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
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: RPC_URL=$(ETHEREUM_RPC_URL)
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TOKEN_A="0x437cc33344a0B27A429f795ff6B469C72698B291" # Wrapped M
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: TOKEN_B="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-wm-usdc-allowlist-hook-and-pool-ethereum: deploy-allowlist-hook-and-pool

deploy-usdc-musd-tick-range-hook-and-pool-ethereum: RPC_URL=$(ETHEREUM_RPC_URL)
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TOKEN_A="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" # USDC
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: TOKEN_B="0xacA92E438df0B2401fF60dA7E4337B687a2435DA" # MUSD
deploy-usdc-musd-tick-range-hook-and-pool-ethereum: deploy-tick-range-hook-and-pool

# Uniswap Pool Management helpers

## Ethereum Mainnet
create-liquidity-position-ethereum :; forge script script/dev/AddLiquidity.s.sol:AddLiquidity --rpc-url mainnet --broadcast -vvv
flashswap-ethereum :; forge script script/dev/FlashSwap.s.sol:FlashSwap --rpc-url mainnet --broadcast -vvv
swap-ethereum :; forge script script/dev/Swap.s.sol:Swap --rpc-url mainnet --broadcast -vvv

## Local 
create-liquidity-position-local :; forge script script/dev/AddLiquidity.s.sol:AddLiquidity --rpc-url localhost --broadcast -vvv
flashswap-local :; forge script script/dev/FlashSwap.s.sol:FlashSwap --rpc-url localhost --broadcast -vvv
swap-local :; forge script script/dev/Swap.s.sol:Swap --rpc-url localhost --broadcast -vvv

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
