#!/bin/bash
source .env

cast rpc anvil_impersonateAccount $MANAGER
cast send $UNISWAP_HOOK \
	--from $MANAGER \
	"setLiquidityProvider(address,bool)" \
	$LIQUIDITY_PROVIDER \
	true \
	--unlocked
