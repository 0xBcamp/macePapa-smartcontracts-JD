// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// install OZ contracts + import Ownable, ReentrancyGuard, IERC20
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract R8R {
    // === STORAGE VARIABLES ===
    address public owner;
    address public robot;
    uint256 public gameId;

    mapping(uint256 gameId => Game) games;

    struct Game {
        uint256 gameId;
        address[] players;
        uint256[] playerRatings;
        uint256 robotRating;
        address winner;
        uint256 winnerPayout;
    }

    // === EVENTS ===
    event GameCreated(uint256 gameId);
    event PlayerJoinedGameWithEth(address player, uint256 gameId);
    event PlayerJoinedGameWithTokens();
    event GameEnded();

    // === ERRORS ===

    // === CONSTRUCTOR ===
    constructor(address _robot) {
        owner = msg.sender;
        robot = _robot;
    }

    // === PUBLIC FUNCTIONS ====
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
            winner: address(0), // set this to our treasury address upon game creation?
            winnerPayout: 0
        });

        // add new game to game mappings indexed by gameId
        games[gameId] = game;

        // emit event
        emit GameCreated(gameId);
    }

    function joinGameWithEth(uint256 _gameId, uint256 _playerRating) public payable {
        // Checks
        require(msg.value > 0, "Please send Eth to enter");
        require(_gameId > 0, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        // Add msg.sender to players array & _playerRating to playerRatings array
        games[_gameId].players.push(msg.sender);
        games[_gameId].playerRatings.push(_playerRating);

        // Interactions - none, Eth accepted into contract

        // emit event
        emit PlayerJoinedGameWithEth(msg.sender, _gameId);
    }

    function joinGameWithTokens(address _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        public
    {}

    function endGame(uint256 _robotRating) public onlyRobot {}

    // === MODIFIERS ===

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRobot() {
        require(msg.sender == owner, "Not owner");
        _;
    }
}
