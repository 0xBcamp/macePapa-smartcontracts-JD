// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {R8R} from "../src/R8R.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract R8RTest is Test {
    R8R public r8r;
    address public ai = makeAddr("ai");
    address public user = makeAddr("user");
    uint256 public gameEntryPriceInEth = 1;
    uint256 public STARTING_BALANCE = 10000;
    ERC20Mock public allowedTestToken;

    event GameCreated(uint256 indexed gameId, uint256 endTimestamp, uint256 gameEntryFee, uint256 prizePool);

    error Error__TokenTransferFailed();

    function setUp() public {
        r8r = new R8R(ai, gameEntryPriceInEth);
        vm.deal(ai, STARTING_BALANCE);
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

    // this test isn't working correctly - REVISIT!
    function testCreateGame_ExpectEmitGameCreated() public {
        vm.startPrank(ai);
        r8r.createGame();
        emit GameCreated(1, block.timestamp, 1, 1);
        vm.stopPrank();
    }

    function testCreateGame_ExpectRevertIfNotAiCaller() public {
        address hacker = makeAddr("hacker");
        vm.startPrank(hacker);
        vm.expectRevert("Only the AI can call this function");
        r8r.createGame();
        vm.stopPrank();
    }

    // =======================
    // === JOIN GAME TESTS ===
    // =======================

    function testJoinGame_WithTokens_ExpectRevertIfTokenNotAllowed() public {
        // create game first
        vm.startPrank(ai);
        r8r.createGame();
        vm.stopPrank();

        // set up mock token for user to send
        ERC20Mock randToken = new ERC20Mock();
        randToken.mint(user, 100e18);

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Token sent is not allowed");
        r8r.joinGame(randToken, 1234, 1, 35);
        vm.stopPrank();
    }

    function testJoinGame_WithTokens_ExpectRevertIfNotEnoughTokensSent() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        // create game first
        vm.startPrank(ai);
        r8r.createGame();
        vm.stopPrank();

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Please send correct amount of tokens to enter");
        r8r.joinGame(allowedTestToken, 2, 1, 35); // user has only sent 2 tokens when the price was set as 3 above
        vm.stopPrank();
    }

    function testJoinGame_WithTokens_ExpectRevertIfGameIdDoesNotExist() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        // create game first
        vm.startPrank(ai);
        r8r.createGame();
        vm.stopPrank();

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Please select a game to enter");
        r8r.joinGame(allowedTestToken, 4, 58, 35); // user has selected a game that doesn't exist: 58
        vm.stopPrank();
    }

    function testJoinGame_WithTokens_ExpectRevertIfRatingIsTooHigh() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        // create game first
        vm.startPrank(ai);
        r8r.createGame();
        vm.stopPrank();

        // join game as user
        vm.startPrank(user);
        vm.expectRevert("Please provide a rating of between 1 - 100");
        r8r.joinGame(allowedTestToken, 4, 1, 256); // user has selected a rating that is over 100: 256
        vm.stopPrank();
    }

    // Test not passing - REVISIT!
    function testJoinGame_WithTokens_ExpectErrorTokenTransferFailed() public {
        // owner adds token + price to allowed tokens
        r8r.addTokenToAllowedList(allowedTestToken, 3);

        // create game first
        vm.startPrank(ai);
        r8r.createGame();
        vm.stopPrank();

        // join game as user
        vm.startPrank(user);
        vm.expectRevert(R8R.Error__TokenTransferFailed.selector);
        r8r.joinGame(allowedTestToken, 4, 1, 35);
        vm.stopPrank();
    }
}
