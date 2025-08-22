#!/bin/bash
source .env

cast rpc anvil_impersonateAccount $MANAGER
cast send $UNISWAP_HOOK \
	--from $MANAGER \
	"setSwapper(address,bool)" \
	$SWAPPER \
	true \
	--unlocked
