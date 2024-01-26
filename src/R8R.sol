// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

<<<<<<< HEAD
import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";
=======
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b

contract R8R is Ownable, ReentrancyGuard {
    // =========================
    // === STORAGE VARIABLES ===
    // =========================

<<<<<<< HEAD
    address public ai;
    uint256 public gameId;
    uint256 public gameEntryPriceInEth;
    uint256 public prizePool = address(this).balance;

    mapping(uint256 gameId => Game) games;
    mapping(IERC20 allowedToken => uint256 tokenEntryPrice) public gameTokensToEntryPrice;

    struct Game {
        uint256 gameId;
        address[] playerKeys;
        mapping(address => uint256) playerAddressesToRatings;
        uint256 gameEntryFeeInEth;
        uint256 numberOfPlayersInGame;
        uint256 aiRating;
        address[] winners;
        uint256 winnerPayout;
        uint256 gameBalance;
        bool gameEnded;
=======
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
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
    }

    // ==============
    // === EVENTS ===
    // ==============

<<<<<<< HEAD
    event GameCreated(uint256 indexed gameId, uint256 endTimestamp, uint256 gameEntryFee, uint256 prizePool);
    event PlayerJoinedGame(address indexed player, uint256 indexed gameId, uint256 playerRating, address token);
    event GameEnded(address[] indexed winners, uint256 payoutPerWinner, uint256 indexed gameId);
=======
    event GameCreated(uint256 gameId);
    event PlayerJoinedGameWithEth(address player, uint256 gameId);
    event PlayerJoinedGameWithTokens(address player, uint256 gameId);
    event GameEnded();
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b

    // ==============
    // === ERRORS ===
    // ==============
    error Error__TokenTransferFailed();
<<<<<<< HEAD
    error Error__JoinWithEitherTokensOrEthNotBoth();
    error Error__GameFeeNotSet();
=======
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b

    // ===================
    // === CONSTRUCTOR ===
    // ===================

<<<<<<< HEAD
    constructor(address _ai, uint256 _gameEntryPriceInEth) Ownable(msg.sender) {
        ai = _ai;
        gameEntryPriceInEth = _gameEntryPriceInEth;
=======
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
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
    }

    // =========================
    // === PUBLIC FUNCTIONS ====
    // =========================

    // @notice called by AI wallet to initialise a new game
    // @notice creates a new Game struct that players + ratings can then be added to when they join
<<<<<<< HEAD
    function createGame() public onlyAi {
        // increment gameId
        gameId = gameId + 1;

        // create game
        Game storage game = games[gameId];

        // add new game to game mappings indexed by gameId
        games[gameId].gameId = game.gameId;

        // emit event
        emit GameCreated(gameId, block.timestamp, games[gameId].gameEntryFeeInEth, prizePool);
    }

    // @notice generic public joinGame function that calls internal functions depending on whether player pays with Eth or ERC20s
    function joinGame(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        public
        payable
        nonReentrant
    {
        require(games[_gameId].gameEnded == false, "The selected game has ended");

        if (msg.value > 0) {
            _joinGameWithEth(_gameId, _playerRating);
        } else if (_amountOfToken > 0) {
            _joinGameWithTokens(_token, _amountOfToken, _gameId, _playerRating);
        } else if (msg.value > 0 && _amountOfToken > 0) {
            Error__JoinWithEitherTokensOrEthNotBoth;
        }
=======
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
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
    }

    // @notice allows new players to join a selected game
    // @param user selects a _gameId to play & submits a rating between 1 - 100 for the image
<<<<<<< HEAD
    function _joinGameWithEth(uint256 _gameId, uint256 _playerRating) internal {
        // Checks
        require(msg.value > 0, "Please send Eth to enter");
        require(msg.value >= gameEntryPriceInEth, "Please send correct amount of Eth to enter");

        // transfer any overpaid Eth to player
        if (msg.value > gameEntryPriceInEth) {
            uint256 refundAmount = msg.value - gameEntryPriceInEth;
            (bool sent,) = payable(msg.sender).call{value: refundAmount}("");
            require(sent, "Failed to refund overpaid Ether");
        }

=======
    function joinGameWithEth(uint256 _gameId, uint256 _playerRating) public payable nonReentrant {
        // Checks
        require(msg.value > 0, "Please send Eth to enter");
        require(msg.value == gameEntryPriceInEth, "Please send correct amount of Eth to enter");
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
<<<<<<< HEAD
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating; // Map player address to their rating within the selected game
        games[_gameId].gameBalance += msg.value; // calc value of msg.value - refund amount
        games[_gameId].numberOfPlayersInGame += 1;
        games[_gameId].playerKeys.push(msg.sender);
        prizePool += msg.value;

        // emit event
        emit PlayerJoinedGame(msg.sender, _gameId, _playerRating, address(0));
=======
        // Add msg.sender to players array & _playerRating to playerRatings array
        games[_gameId].players.push(msg.sender);
        games[_gameId].playerRatings.push(_playerRating);

        // Interactions - none, Eth accepted into contract

        // emit event
        emit PlayerJoinedGameWithEth(msg.sender, _gameId);
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
    }

    // @notice allows new players to join a selected game using ERC20 tokens
    // @param players must pass in an amount of an allow-listed token along with their selected _gameId & image rating
<<<<<<< HEAD
    function _joinGameWithTokens(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        internal
=======
    function joinGameWithTokens(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        public
        nonReentrant
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
    {
        // Checks
        require(_amountOfToken > 0, "Please send a token amount of more than zero to enter");

        // check that token is on the list of allowed tokens & get the entry price denominated in that token
        bool tokenAllowed;
        uint256 tokenEntryPrice;

<<<<<<< HEAD
        if (gameTokensToEntryPrice[_token] > 0) {
            tokenAllowed = true;
            tokenEntryPrice = gameTokensToEntryPrice[_token];
        }

        require(tokenAllowed == true, "Token sent is not allowed");
        require(_amountOfToken >= tokenEntryPrice, "Please send correct amount of tokens to enter");
=======
        for (uint256 i = 0; i < gameTokensAllowedList.length; i++) {
            if (gameTokensAllowedList[i] == _token) {
                tokenAllowed = true;
                tokenEntryPrice = gameTokensEntryPriceList[i];
            }
        }

        require(tokenAllowed == true, "Token sent is not allowed");

        // check that the user has sent the correct price of entry in tokens
        require(_amountOfToken == tokenEntryPrice, "Please send correct amount of tokens to enter");

>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
<<<<<<< HEAD
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating;
        games[_gameId].numberOfPlayersInGame += 1;
        games[_gameId].playerKeys.push(msg.sender);

        // *** ACCOUNTING FOR ERC20S REQUIRED ***
=======
        // Add msg.sender to players array & _playerRating to playerRatings array
        games[_gameId].players.push(msg.sender);
        games[_gameId].playerRatings.push(_playerRating);
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b

        // Interactions
        // transfer tokens from player to contract (EOA approval required beforehand)
        bool success = _token.transferFrom(msg.sender, address(this), _amountOfToken);
        if (success != true) {
            Error__TokenTransferFailed;
        }

        // emit event
<<<<<<< HEAD
        emit PlayerJoinedGame(msg.sender, _gameId, _playerRating, address(_token));
    }

    function endGame(uint256 _aiRating, uint256 _gameId) public onlyAi {
        // set gameEnded to true so nobody else can join
        games[_gameId].gameEnded = true;

        // loop over player ratings and...
        for (uint256 i = 0; i < games[_gameId].numberOfPlayersInGame; i++) {
            // ...compare each player rating to the AI one
            if (games[_gameId].playerAddressesToRatings[games[_gameId].playerKeys[i]] == _aiRating) {
                // store any winners in the winners array
                games[_gameId].winners[i] = games[_gameId].playerKeys[i];
            } else {
                games[_gameId].winners[0] = address(0); // end game if no winners
                emit GameEnded(games[_gameId].winners, 0, _gameId);
            }
        }

        // prize pool / winners
        uint256 payoutPerWinner = prizePool / games[_gameId].winners.length;
        prizePool = 0; // prizePool reset to zero after pot is won

        // send ether to winners
        for (uint256 j = 0; j < games[_gameId].winners.length; j++) {
            (bool sent,) = payable(games[_gameId].winners[j]).call{value: payoutPerWinner}("");
            require(sent, "Payout to winner failed");
        }

        emit GameEnded(games[_gameId].winners, payoutPerWinner, _gameId);
    }

    // @notice add token to allowed list with entry price in that token
    function addTokenToAllowedList(IERC20 _token, uint256 _tokenEntryPrice) public onlyOwner {
        gameTokensToEntryPrice[_token] = _tokenEntryPrice;
    }

    function setGameFee(IERC20 _token, uint256 _tokenEntryPrice, uint256 _ethEntryPrice) public onlyOwner {
        if (gameTokensToEntryPrice[_token] > 0) {
            gameTokensToEntryPrice[_token] = _tokenEntryPrice;
        } else if (_ethEntryPrice > 0) {
            gameEntryPriceInEth = _ethEntryPrice;
        } else {
            Error__GameFeeNotSet;
        }
    }

    function getGameFee(IERC20 _token, bool _getEthPrice) public view returns (uint256) {
        if (_getEthPrice == true) {
            return gameEntryPriceInEth;
        }
        if (gameTokensToEntryPrice[_token] > 0) {
            return gameTokensToEntryPrice[_token];
        }
=======
        emit PlayerJoinedGameWithTokens(msg.sender, _gameId);
    }

    function endGame(uint256 _robotRating) public onlyRobot {}

    function addTokenToAllowedList(IERC20 _token) public onlyOwner {
        gameTokensAllowedList.push(_token);
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
    }

    // =================
    // === MODIFIERS ===
    // =================

<<<<<<< HEAD
    modifier onlyAi() {
        require(msg.sender == ai, "Only the AI can call this function");
=======
    modifier onlyRobot() {
        require(msg.sender == robot, "Only the AI can call this function");
>>>>>>> 9189b408491004e3b45ea73613692df75bda426b
        _;
    }
}
