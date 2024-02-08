// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {R8R} from "../src/R8R.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract R8RTest is Test {
    R8R public r8r;
    address public ai = makeAddr("ai");
    address public user = makeAddr("user");
    address public mary = makeAddr("mary");
    uint256 public gameEntryPriceInEth = 1e18;
    uint256 public STARTING_BALANCE = 10000;
    ERC20Mock public allowedTestToken;

    event GameCreated(uint256 indexed gameId, uint256 endTimestamp, uint256 gameEntryFee, uint256 prizePool);
    event PlayerJoinedGame(address indexed player, uint256 indexed gameId, uint256 playerRating, address token);
    event GameEnded(address[] indexed winners, uint256 payoutPerWinner, uint256 indexed gameId);
    event GameEndedTest(address indexed winners, uint256 payoutPerWinner, uint256 indexed gameId);

    error Error__TokenTransferFailed();
    error Error__PrizePoolIsEmpty();
    error ERC20InsufficientAllowance(address, uint256, uint256);

    function setUp() public {
        r8r = new R8R(ai, gameEntryPriceInEth);
        // deal Eth
        vm.deal(ai, STARTING_BALANCE);
        vm.deal(user, STARTING_BALANCE);
        vm.deal(mary, STARTING_BALANCE);
        // create & mint mock token
        allowedTestToken = new ERC20Mock();
        allowedTestToken.mint(address(this), 50e18);
        allowedTestToken.mint(user, 50e18);
    }

    // =========================
    // === CREATE GAME TESTS ===
    // =========================

    function testCreateGame_GameIdIncremented() public {
        vm.startPrank(ai);
        r8r.createGame();
        // gameId should be '1' after initial game creation
        assertEq(r8r.gameId(), 1);
        vm.stopPrank();
    }

    function testCreateGame_ExpectEmit_GameCreated() public {
        vm.startPrank(ai);
        vm.expectEmit(true, true, false, true);
        emit GameCreated(1, (block.timestamp + 600), 1e18, 0);
        r8r.createGame();
        vm.stopPrank();
    }

    function testCreateGame_ExpectRevert_IfNotAiCaller() public {
        address hacker = makeAddr("hacker");
        vm.startPrank(hacker);
        vm.expectRevert("Only the AI can call this function");
        r8r.createGame();
        vm.stopPrank();
    }

    // =======================
    // === JOIN GAME TESTS ===
    // =======================

    // === JOIN GAME WITH TOKENS TESTS ===

    function testJoinGame_WithTokens_ExpectRevert_IfTokenNotAllowed() public {
        _createGameAsAi();

        // set up mock token for user to send
        ERC20Mock randToken = new ERC20Mock();
        randToken.mint(user, 100e18);

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Token sent is not allowed");
        r8r.joinGame(randToken, 1234, 1, 35);
        vm.stopPrank();
    }

    function testJoinGame_WithTokens_ExpectRevert_IfNotEnoughTokensSent() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Please send correct amount of tokens to enter");
        r8r.joinGame(allowedTestToken, 2, 1, 35); // user has only sent 2 tokens when the price was set as 3 above
        vm.stopPrank();
    }

    function testJoinGame_WithTokens_ExpectRevert_IfGameIdDoesNotExist() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Please select a game to enter");
        r8r.joinGame(allowedTestToken, 4, 58, 35); // user has selected a game that doesn't exist: 58
        vm.stopPrank();
    }

    function testJoinGame_WithTokens_ExpectRevert_IfRatingIsTooHigh() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Please provide a rating of between 1 - 100");
        r8r.joinGame(allowedTestToken, 4, 1, 256); // user has selected a rating that is over 100: 256
        vm.stopPrank();
    }

    function testJoinGame_WithTokens_ExpectError_ERC20InsufficientAllowance() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        // vm.expectRevert(abi.encodeWithSelector(Error__TokenTransferFailed.selector));
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientAllowance.selector, 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, 0, 4
            )
        );
        r8r.joinGame(allowedTestToken, 4, 1, 35);
        vm.stopPrank();
    }

    // Test not passing - reverting with ERC20InsufficientAllowance from step before - REVISIT!
    function testJoinGame_WithTokens_ExpectEmit_PlayerJoinedGame() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        _createGameAsAi();

        // join game as user
        vm.startPrank(user);

        // approve contract to spend user's tokens
        allowedTestToken.approve(address(r8r), 100);

        vm.expectEmit(true, true, false, true);
        emit PlayerJoinedGame(user, 1, 35, address(allowedTestToken));
        r8r.joinGame(allowedTestToken, 4, 1, 35);
        vm.stopPrank();
    }

    // === JOIN GAME WITH ETH TESTS ===

    function testJoinGame_WithEth_ExpectEmit_PlayerJoinedGame() public {
        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.deal(user, 100e18);
        vm.expectEmit(true, true, false, true);
        emit PlayerJoinedGame(user, 1, 35, address(allowedTestToken));
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();
    }

    function testJoinGame_WithEth_ExpectRevert_IfNotEnoughEth() public {
        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.deal(user, 100e18);
        vm.expectRevert("Please send correct amount of Eth to enter");
        r8r.joinGame{value: 100000}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();
    }

    function testJoinGame_WithEth_GameVariablesShouldBeSet_OnePlayer() public {
        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.deal(user, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();

        uint256 testGameId = 1;

        (
            uint256 gameId,
            // address[] memory playerKeys,
            // mapping(address => uint256) memory playerAddressesToRatings,
            uint256 gameEntryFeeInEth,
            uint256 numberOfPlayersInGame,
            uint256 aiRating,
            // address[] memory winners,
            uint256 winnerPayout,
            uint256 gameBalance,
            bool gameEnded
        ) = r8r.games(testGameId);

        assertEq(gameId, 1);
        assertEq(gameEntryFeeInEth, 1e18);
        assertEq(numberOfPlayersInGame, 1);
        assertEq(aiRating, 0);
        assertEq(winnerPayout, 0);
        assertEq(gameBalance, 1e18);
        assertEq(gameEnded, false);
    }

    function testJoinGame_WithEth_PlayerRatingShouldBeSetInGameStructMapping() public {
        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.deal(user, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();

        uint256 testGameId = 1;

        uint256 playerRating = r8r.getRatingFromPlayerAddress(testGameId, user);

        assertEq(playerRating, 35);
    }

    function testJoinGame_WithEth_PlayerCanJoinMultipleGames() public {
        _createGameAsAi(); // create Game 1
        _createGameAsAi(); // create Game 2

        // join Game 1 as user
        vm.startPrank(user);
        vm.deal(user, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();

        // join Game 2 as user
        vm.startPrank(user);
        vm.deal(user, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 2, 78);
        vm.stopPrank();

        uint256 testGameId1 = 1;
        uint256 testGameId2 = 2;

        (,, uint256 numberOfPlayersInGame1,,,,) = r8r.games(testGameId1);
        (,, uint256 numberOfPlayersInGame2,,,,) = r8r.games(testGameId2);

        assertEq(testGameId1, 1);
        assertEq(numberOfPlayersInGame1, 1);
        assertEq(testGameId2, 2);
        assertEq(numberOfPlayersInGame2, 1);
    }

    function testJoinGame_WithEth_MultiplePlayersCanJoinMultipleGames() public {
        _createGameAsAi(); // create Game 1
        _createGameAsAi(); // create Game 2
        _createGameAsAi(); // create Game 3
        _createGameAsAi(); // create Game 4

        // join Games 1, 2 and 3 as 'user'
        vm.startPrank(user);
        vm.deal(user, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 2, 78);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 3, 23);
        vm.stopPrank();

        // join Games 2, 3 and 4 as 'mary'
        vm.startPrank(mary);
        vm.deal(mary, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 2, 91);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 3, 14);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 4, 49);
        vm.stopPrank();

        uint256 testGameId1 = 1;
        uint256 testGameId2 = 2;
        uint256 testGameId3 = 3;
        uint256 testGameId4 = 4;

        (,, uint256 numberOfPlayersInGame1,,,,) = r8r.games(testGameId1);
        (,, uint256 numberOfPlayersInGame2,,,,) = r8r.games(testGameId2);
        (,, uint256 numberOfPlayersInGame3,,,,) = r8r.games(testGameId3);
        (,, uint256 numberOfPlayersInGame4,,,,) = r8r.games(testGameId4);

        // Game 1 == 1 player
        assertEq(testGameId1, 1);
        assertEq(numberOfPlayersInGame1, 1);
        // Game 2 == 2 players
        assertEq(testGameId2, 2);
        assertEq(numberOfPlayersInGame2, 2);
        // Game 3 == 2 players
        assertEq(testGameId3, 3);
        assertEq(numberOfPlayersInGame3, 2);
        // Game 4 == 1 player
        assertEq(testGameId4, 4);
        assertEq(numberOfPlayersInGame4, 1);
    }

    function testJoinGame_WithEth_GameVariablesShouldBeSet_ThreePlayers() public {
        _createGameAsAi();

        // join game as user
        vm.startPrank(user);
        vm.deal(user, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();

        // join game as bob
        address bob = makeAddr("bob");
        vm.startPrank(bob);
        vm.deal(bob, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();

        // join game as alice
        address alice = makeAddr("alice");
        vm.startPrank(alice);
        vm.deal(alice, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();

        uint256 testGameId = 1;

        (
            uint256 gameId,
            // address[] memory playerKeys,
            // mapping(address => uint256) memory playerAddressesToRatings,
            uint256 gameEntryFeeInEth,
            uint256 numberOfPlayersInGame,
            uint256 aiRating,
            // address[] memory winners,
            uint256 winnerPayout,
            uint256 gameBalance,
            bool gameEnded
        ) = r8r.games(testGameId);

        assertEq(gameId, 1);
        assertEq(gameEntryFeeInEth, 1e18);
        assertEq(numberOfPlayersInGame, 3);
        assertEq(aiRating, 0);
        assertEq(winnerPayout, 0);
        assertEq(gameBalance, 3e18);
        assertEq(gameEnded, false);
    }

    // ======================
    // === END GAME TESTS ===
    // ======================

    function testEndGame_ExpectRevert_IfPrizePoolIsEmpty() public {
        _createGameAsAi();

        // join game as user
        vm.startPrank(ai);
        vm.expectRevert(abi.encodeWithSelector(Error__PrizePoolIsEmpty.selector));
        r8r.endGame(1, 35);
        vm.stopPrank();
    }

    function testEndGame_ExpectEmit_GameEndedWithNoWinners() public {
        _createGameAsAi();
        _joinGameWithEth(); // _joinGameWithEth joins as user with a rating prediction of 35

        address[] memory noWinners = new address[](1);
        noWinners[0] = address(0);

        vm.startPrank(ai);
        vm.expectEmit(true, true, false, true);
        emit GameEnded(noWinners, 0, 1);
        r8r.endGame(1, 64); // AI predicts 64, user predicted 35
        vm.stopPrank();
    }

    function testEndGame_ExpectEmit_GameEndedWithWinner() public {
        _createGameAsAi();
        _joinGameWithEth(); // _joinGameWithEth joins as user with a rating prediction of 35

        address[] memory userIsWinner = new address[](1);
        userIsWinner[0] = user;

        vm.startPrank(ai);
        vm.expectEmit(true, true, false, true);
        emit GameEnded(userIsWinner, 1e18, 1);
        r8r.endGame(1, 35); // 35 == same score as user predicted
        vm.stopPrank();
    }

    function testEndGame_ExpectEmit_GameEndedWithTwoWinners() public {
        _createGameAsAi();
        _joinGameWithEth(); // _joinGameWithEth joins as user with a rating prediction of 35

        // join game as Mary, sending 2 eth
        vm.startPrank(mary);
        vm.deal(mary, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35); // mary joins the game with a prediction of 35 also
        vm.stopPrank();

        address[] memory winners = new address[](2);
        winners[0] = user;
        winners[1] = mary;

        vm.startPrank(ai);
        vm.expectEmit(true, true, false, true);
        emit GameEnded(winners, 1e18, 1);
        r8r.endGame(1, 35); // 35 == same score as user predicted
        vm.stopPrank();
    }

    function testEndGame_ExpectEmit_GameEndedWithTwoWinners_CheckAddresses() public {
        _createGameAsAi();
        _joinGameWithEth(); // _joinGameWithEth joins as user with a rating prediction of 35

        // join game as Mary, sending 2 eth
        vm.startPrank(mary);
        vm.deal(mary, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35); // mary joins the game with a prediction of 35 also
        vm.stopPrank();

        // end game
        vm.startPrank(ai);
        r8r.endGame(1, 35); // 35 == same score as user predicted
        vm.stopPrank();

        // memory array to use in assertion below
        address[] memory winners = new address[](2);
        winners[0] = user;
        winners[1] = mary;

        // get the winners from the contract
        address[] memory winnersArray = r8r.getWinnersFromGameId(1);

        // assert that the array of winners created here == the array of winners returned from the contract
        assertEq(winnersArray[0], winners[0]);
        assertEq(winnersArray[1], winners[1]);
    }

    // ===============================
    // === GETTERS & SETTERS TESTS ===
    // ===============================

    function testAddTokenToAllowedList() public {
        r8r.addTokenToAllowedList(allowedTestToken, 3);
        uint256 tokenPrice = r8r.gameTokensToEntryPrice(allowedTestToken);
        assertEq(tokenPrice, 3);
    }

    function testSetGameFee_InTokens() public {
        // set entry fee in both specified token & eth
        r8r.addTokenToAllowedList(allowedTestToken, 3); // add token to allow list first
        r8r.setGameFee(allowedTestToken, 7, 0); // set token entry fee
        uint256 gameFeeInToken = r8r.getGameFee(allowedTestToken, false);
        assertEq(gameFeeInToken, 7);
    }

    function testSetGameFee_InEth() public {
        // set entry fee in both specified token & eth
        r8r.setGameFee(allowedTestToken, 0, 4e18); // set eth entry fee
        uint256 gameFeeInEth = r8r.getGameFee(allowedTestToken, true);
        assertEq(gameFeeInEth, 4e18);
    }

    function testGetGameFee_InTokens() public {
        r8r.addTokenToAllowedList(allowedTestToken, 5);
        uint256 gameFeeInToken = r8r.getGameFee(allowedTestToken, false);
        assertEq(gameFeeInToken, 5);
    }

    function testGetGameFee_InEth() public {
        uint256 gameFeeInEth = r8r.getGameFee(allowedTestToken, true);
        assertEq(gameFeeInEth, 1e18);
    }

    // ===============
    // === HELPERS ===
    // ===============

    function _createGameAsAi() public {
        // create game first
        vm.startPrank(ai);
        r8r.createGame();
        vm.stopPrank();
    }

    function _joinGameWithEth() public {
        // join game as user, sending 2 eth
        vm.startPrank(user);
        vm.deal(user, 100e18);
        r8r.joinGame{value: 2 ether}(allowedTestToken, 0, 1, 35);
        vm.stopPrank();
    }
}
