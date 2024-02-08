-include .env

deploy:
	forge create src/R8R.sol:R8R --private-key $(R8R_DEPLOYER_PK) --constructor-args $(R8R_AI_ADDRESS) 1 --rpc-url $(FTM_RPC_URL)

create-game:
	cast send $(R8R_CONTRACT) "createGame()" --private-key $(R8R_AI_PK) --rpc-url $(FTM_RPC_URL)

join-game:
	cast send $(R8R_CONTRACT) "joinGame(address,uint,uint,uint)" $(ZERO_ADDRESS) 0 1 35 --private-key $(R8R_PLAYER_PK) --rpc-url $(FTM_RPC_URL)

join-game-as-player-2:
	cast send $(R8R_CONTRACT) "joinGame(address,uint,uint,uint)" $(ZERO_ADDRESS) 0 1 35 --private-key $(R8R_PLAYER_2_PK) --rpc-url $(FTM_RPC_URL)

join-game-with-eth:
	cast send $(R8R_CONTRACT) "joinGame(address,uint,uint,uint)" $(ZERO_ADDRESS) 0 1 87 --private-key $(R8R_PLAYER_PK) --rpc-url $(FTM_RPC_URL) --value "0.1ether"

join-game-with-eth-player-2:
	cast send $(R8R_CONTRACT) "joinGame(address,uint,uint,uint)" $(ZERO_ADDRESS) 0 5 66 --private-key $(R8R_PLAYER_2_PK) --rpc-url $(FTM_RPC_URL) --value "0.1ether"

get-entry-fee-in-eth:
	cast call $(R8R_CONTRACT) "getGameFee(address,bool)" $(ZERO_ADDRESS) true --rpc-url $(FTM_RPC_URL)

get-prize-pool:
	cast call $(R8R_CONTRACT) "prizePool()(uint)" --rpc-url $(FTM_RPC_URL)

end-game:
	cast send $(R8R_CONTRACT) "endGame(uint,uint)" 5 66 --private-key $(R8R_AI_PK) --rpc-url $(FTM_RPC_URL)

verify-deployed-contract-on-ftm-testnet:
	forge verify-contract --chain-id 4002 --constructor-args-path constructor-args.txt --watch $(R8R_CONTRACT) src/R8R.sol:R8R --etherscan-api-key $(FTM_SCAN_KEY)