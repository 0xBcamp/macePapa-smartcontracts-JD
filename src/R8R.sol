// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract R8R is Ownable, ReentrancyGuard {
    // =========================
    // === STORAGE VARIABLES ===
    // =========================

    address public robot;
    uint256 public gameId;
    uint256 public gameEntryPriceInEth;

    mapping(uint256 gameId => Game) games;

    IERC20[] public gameTokensAllowedList; // list of ERC20 tokens users can use to enter the game
    uint256[] public gameTokensEntryPriceList; // list of entry price for the ERC20 tokens

    struct Game {
        uint256 gameId;
        address[] players;
        uint256[] playerRatings;
        uint256 robotRating;
        address winner;
        uint256 winnerPayout;
    }

    // ==============
    // === EVENTS ===
    // ==============

    event GameCreated(uint256 gameId);
    event PlayerJoinedGameWithEth(address player, uint256 gameId);
    event PlayerJoinedGameWithTokens(address player, uint256 gameId);
    event GameEnded();

    // ==============
    // === ERRORS ===
    // ==============
    error Error__TokenTransferFailed();

    // ===================
    // === CONSTRUCTOR ===
    // ===================

    constructor(
        address _robot,
        uint256 _gameEntryPriceInEth,
        IERC20[] memory _gameTokensAllowedList,
        uint256[] memory _gameTokensEntryPriceList
    ) Ownable(msg.sender) {
        robot = _robot;
        gameEntryPriceInEth = _gameEntryPriceInEth;
        gameTokensAllowedList = _gameTokensAllowedList;
        gameTokensEntryPriceList = _gameTokensEntryPriceList;
    }

    // =========================
    // === PUBLIC FUNCTIONS ====
    // =========================

    // @notice called by AI wallet to initialise a new game
    // @notice creates a new Game struct that players + ratings can then be added to when they join
    function createGame() public onlyRobot {
        // increment gameId
        gameId = gameId + 1;

        // empty placeholder arrays for players + their ratings (until someone joins the game)
        address[] memory playersArray;
        uint256[] memory playersRatingsArray;

        // create game
        Game memory game = Game({
            gameId: gameId,
            players: playersArray,
            playerRatings: playersRatingsArray,
            robotRating: 0,
            winner: address(0), // set this to our treasury address upon initial game creation??
            winnerPayout: 0
        });

        // add new game to game mappings indexed by gameId
        games[gameId] = game;

        // emit event
        emit GameCreated(gameId);
    }

    // @notice allows new players to join a selected game
    // @param user selects a _gameId to play & submits a rating between 1 - 100 for the image
    function joinGameWithEth(uint256 _gameId, uint256 _playerRating) public payable nonReentrant {
        // Checks
        require(msg.value > 0, "Please send Eth to enter");
        require(msg.value == gameEntryPriceInEth, "Please send correct amount of Eth to enter");
        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        // Add msg.sender to players array & _playerRating to playerRatings array
        games[_gameId].players.push(msg.sender);
        games[_gameId].playerRatings.push(_playerRating);

        // Interactions - none, Eth accepted into contract

        // emit event
        emit PlayerJoinedGameWithEth(msg.sender, _gameId);
    }

    // @notice allows new players to join a selected game using ERC20 tokens
    // @param players must pass in an amount of an allow-listed token along with their selected _gameId & image rating
    function joinGameWithTokens(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        public
        nonReentrant
    {
        // Checks
        require(_amountOfToken > 0, "Please send a token amount of more than zero to enter");

        // check that token is on the list of allowed tokens & get the entry price denominated in that token
        bool tokenAllowed;
        uint256 tokenEntryPrice;

        for (uint256 i = 0; i < gameTokensAllowedList.length; i++) {
            if (gameTokensAllowedList[i] == _token) {
                tokenAllowed = true;
                tokenEntryPrice = gameTokensEntryPriceList[i];
            }
        }

        require(tokenAllowed == true, "Token sent is not allowed");

        // check that the user has sent the correct price of entry in tokens
        require(_amountOfToken == tokenEntryPrice, "Please send correct amount of tokens to enter");

        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        // Add msg.sender to players array & _playerRating to playerRatings array
        games[_gameId].players.push(msg.sender);
        games[_gameId].playerRatings.push(_playerRating);

        // Interactions
        // transfer tokens from player to contract (EOA approval required beforehand)
        bool success = _token.transferFrom(msg.sender, address(this), _amountOfToken);
        if (success != true) {
            Error__TokenTransferFailed;
        }

        // emit event
        emit PlayerJoinedGameWithTokens(msg.sender, _gameId);
    }

    function endGame(uint256 _robotRating) public onlyRobot {}

    function addTokenToAllowedList(IERC20 _token) public onlyOwner {
        gameTokensAllowedList.push(_token);
    }

    // =================
    // === MODIFIERS ===
    // =================

    modifier onlyRobot() {
        require(msg.sender == robot, "Only the AI can call this function");
        _;
    }
}
