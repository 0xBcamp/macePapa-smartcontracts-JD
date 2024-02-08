// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";

contract R8R is Ownable, ReentrancyGuard {
    // =========================
    // === STORAGE VARIABLES ===
    // =========================

    address public ai;
    uint256 public gameId;
    uint256 public gameEntryPriceInEth;
    uint256 public prizePool = address(this).balance;

    mapping(uint256 gameId => Game) public games;
    mapping(IERC20 allowedToken => uint256 tokenEntryPrice) public gameTokensToEntryPrice;

    struct Game {
        uint256 gameId;
        address[] playerKeys;
        mapping(address => uint256) playerAddressesToRatings;
        uint256 gameEntryPriceInEth;
        uint256 numberOfPlayersInGame;
        uint256 aiRating;
        address[] winners;
        uint256 winnerPayout;
        uint256 gameBalance;
        bool gameEnded;
    }

    // ==============
    // === EVENTS ===
    // ==============

    event GameCreated(uint256 indexed gameId, uint256 endTimestamp, uint256 gameEntryFee, uint256 prizePool);
    event PlayerJoinedGame(address indexed player, uint256 indexed gameId, uint256 playerRating, address token);
    event GameEnded(address[] indexed winners, uint256 payoutPerWinner, uint256 indexed gameId);
    event GameEndedTest(address indexed winner, uint256 payoutPerWinner, uint256 indexed gameId);

    // ==============
    // === ERRORS ===
    // ==============
    error Error__TokenTransferFailed();
    error Error__JoinWithEitherTokensOrEthNotBoth();
    error Error__GameFeeNotSet();
    error Error__PrizePoolIsEmpty();

    // ===================
    // === CONSTRUCTOR ===
    // ===================

    constructor(address _ai, uint256 _gameEntryPriceInEth) Ownable(msg.sender) {
        ai = _ai;
        gameEntryPriceInEth = _gameEntryPriceInEth;
    }

    // =========================
    // === PUBLIC FUNCTIONS ====
    // =========================

    // @notice called by AI wallet to initialise a new game
    // @notice creates a new Game struct that players + ratings can then be added to when they join
    function createGame() public onlyAi {
        // increment gameId
        gameId = gameId + 1;

        // Create new Game struct
        Game storage game = games[gameId];

        // add new game to game mappings indexed by gameId
        game.gameEntryPriceInEth = gameEntryPriceInEth;
        game.gameId = gameId;
        game.gameEntryPriceInEth = 1e18;
        uint256 endTimestamp = (block.timestamp + 600);
        game.playerAddressesToRatings;

        // emit event
        emit GameCreated(game.gameId, endTimestamp, game.gameEntryPriceInEth, prizePool);
    }

    // @notice generic public joinGame function that calls internal functions depending on whether player pays with Eth or ERC20s
    function joinGame(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        public
        payable
        nonReentrant
    {
        // require(games[_gameId].gameEnded == false, "The selected game has ended");

        if (msg.value > 0) {
            _joinGameWithEth(_token, _gameId, _playerRating);
        } else if (_amountOfToken > 0) {
            _joinGameWithTokens(_token, _amountOfToken, _gameId, _playerRating);
        } else if (msg.value > 0 && _amountOfToken > 0) {
            revert Error__JoinWithEitherTokensOrEthNotBoth();
        }
    }

    // @notice allows new players to join a selected game
    // @param user selects a _gameId to play & submits a rating between 1 - 100 for the image
    function _joinGameWithEth(IERC20 _token, uint256 _gameId, uint256 _playerRating) internal {
        // Checks
        require(msg.value > 0, "Please send Eth to enter");
        require(msg.value >= gameEntryPriceInEth, "Please send correct amount of Eth to enter");

        uint256 refundAmount = 0;

        // transfer any overpaid Eth to player
        if (msg.value > gameEntryPriceInEth) {
            refundAmount = msg.value - gameEntryPriceInEth;
            (bool sent,) = payable(msg.sender).call{value: refundAmount}("");
            require(sent, "Failed to refund overpaid Ether");
        }

        uint256 ethValueSentMinusRefund = (msg.value - refundAmount);

        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating; // Map player address to their rating within the selected game
        games[_gameId].gameBalance += ethValueSentMinusRefund; // calc value of msg.value - refund amount
        games[_gameId].numberOfPlayersInGame += 1;
        games[_gameId].playerKeys.push(msg.sender);
        prizePool += ethValueSentMinusRefund;

        // emit event
        emit PlayerJoinedGame(msg.sender, _gameId, _playerRating, address(_token));
    }

    // @notice allows new players to join a selected game using ERC20 tokens
    // @param players must pass in an amount of an allow-listed token along with their selected _gameId & image rating
    function _joinGameWithTokens(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        internal
    {
        // Checks
        require(_amountOfToken > 0, "Please send a token amount of more than zero to enter");

        // check that token is on the list of allowed tokens & get the entry price denominated in that token
        bool tokenAllowed;
        uint256 tokenEntryPrice;

        if (gameTokensToEntryPrice[_token] > 0) {
            tokenAllowed = true;
            tokenEntryPrice = gameTokensToEntryPrice[_token];
        }

        require(tokenAllowed == true, "Token sent is not allowed");
        require(_amountOfToken >= tokenEntryPrice, "Please send correct amount of tokens to enter");
        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating;
        games[_gameId].numberOfPlayersInGame += 1;
        games[_gameId].playerKeys.push(msg.sender);

        // *** ACCOUNTING FOR ERC20S REQUIRED ***

        // Interactions
        // transfer tokens from player to contract (EOA approval required beforehand)
        bool success = _token.transferFrom(msg.sender, address(this), _amountOfToken);
        if (success != true) {
            revert Error__TokenTransferFailed();
        }

        // emit event
        emit PlayerJoinedGame(msg.sender, _gameId, _playerRating, address(_token));
    }

    function endGame(uint256 _gameId, uint256 _aiRating) public onlyAi {
        // set gameEnded to true so nobody else can join
        games[_gameId].gameEnded = true;

        // loop over player ratings and...
        for (uint256 i = 0; i < games[_gameId].numberOfPlayersInGame; i++) {
            // ...compare each player rating to the AI one
            if (games[_gameId].playerAddressesToRatings[games[_gameId].playerKeys[i]] == _aiRating) {
                // store any winners in the winners array
                games[_gameId].winners.push(games[_gameId].playerKeys[i]);
            } else {
                games[_gameId].winners.push(address(0)); // end game if no winners
                emit GameEnded(games[_gameId].winners, 0, _gameId);
            }
        }

        // prize pool / winners
        if (prizePool == 0) {
            revert Error__PrizePoolIsEmpty();
        }
        uint256 payoutPerWinner = prizePool / games[_gameId].winners.length;
        prizePool = 0; // prizePool reset to zero after pot is won

        // send ether to winners
        for (uint256 j = 0; j < games[_gameId].winners.length; j++) {
            (bool sent,) = payable(games[_gameId].winners[j]).call{value: payoutPerWinner}("");
            require(sent, "Payout to winner failed");
        }

        emit GameEnded(games[_gameId].winners, payoutPerWinner, _gameId);
    }

    // =========================
    // === GETTERS / SETTERS ===
    // =========================

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
            revert Error__GameFeeNotSet();
        }
    }

    function getGameFee(IERC20 _token, bool _getEthPrice) public view returns (uint256 price) {
        if (_getEthPrice == true) {
            return gameEntryPriceInEth;
        }
        if (gameTokensToEntryPrice[_token] > 0) {
            return gameTokensToEntryPrice[_token];
        }
    }

    function getRatingFromPlayerAddress(uint256 _gameId, address _player) public view returns (uint256 playerRating) {
        Game storage game = games[_gameId];
        return game.playerAddressesToRatings[_player];
    }

    function getWinnersFromGameId(uint256 _gameId) public view returns (address[] memory winners) {
        Game storage game = games[_gameId];
        return game.winners;
    }

    // =================
    // === MODIFIERS ===
    // =================

    modifier onlyAi() {
        require(msg.sender == ai, "Only the AI can call this function");
        _;
    }
}
