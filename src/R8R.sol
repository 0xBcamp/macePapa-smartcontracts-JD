// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract R8R is Ownable, ReentrancyGuard {
    // =========================
    // === STORAGE VARIABLES ===
    // =========================

    address public ai;
    uint256 public gameId;
    uint256 public gameEntryPriceInEth;
    uint256 public prizePool = address(this).balance;

    mapping(uint256 gameId => Game) games;

    IERC20[] public gameTokensAllowedList; // list of ERC20 tokens users can use to enter the game
    uint256[] public gameTokensEntryPriceList; // list of entry price for the ERC20 tokens

    struct Game {
        uint256 gameId;
        mapping(address => uint256) playerAddressesToRatings;
        uint256 aiRating;
        address winner;
        uint256 winnerPayout;
        uint256 gameBalance;
    }

    // ==============
    // === EVENTS ===
    // ==============

    event GameCreated(uint256 gameId, uint256 timestamp, uint256 prizePool);
    event PlayerJoinedGameWithEth(address player, uint256 gameId, uint256 playerRating);
    event PlayerJoinedGameWithTokens(address player, uint256 gameId, uint256 playerRating);
    event GameEnded();

    // ==============
    // === ERRORS ===
    // ==============
    error Error__TokenTransferFailed();
    error Error__JoinWithEitherTokensOrEthNotBoth();

    // ===================
    // === CONSTRUCTOR ===
    // ===================

    constructor(
        address _ai,
        uint256 _gameEntryPriceInEth,
        IERC20[] memory _gameTokensAllowedList,
        uint256[] memory _gameTokensEntryPriceList
    ) Ownable(msg.sender) {
        ai = _ai;
        gameEntryPriceInEth = _gameEntryPriceInEth;
        gameTokensAllowedList = _gameTokensAllowedList;
        gameTokensEntryPriceList = _gameTokensEntryPriceList;
    }

    // =========================
    // === PUBLIC FUNCTIONS ====
    // =========================

    // @notice called by AI wallet to initialise a new game
    // @notice creates a new Game struct that players + ratings can then be added to when they join
    function createGame() public onlyAi {
        // increment gameId
        gameId = gameId + 1;

        // create game
        Game storage game = games[gameId];

        // add new game to game mappings indexed by gameId
        games[gameId].gameId = game.gameId;

        // emit event
        emit GameCreated(gameId, block.timestamp, prizePool);
    }

    // @notice generic public joinGame function that calls internal functions depending on whether player pays with Eth or ERC20s
    function joinGame(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        public
        payable
        nonReentrant
    {
        if (msg.value > 0) {
            _joinGameWithEth(_gameId, _playerRating);
        } else if (_amountOfToken > 0) {
            _joinGameWithTokens(_token, _amountOfToken, _gameId, _playerRating);
        } else if (msg.value > 0 && _amountOfToken > 0) {
            Error__JoinWithEitherTokensOrEthNotBoth;
        } else {}
    }

    // @notice allows new players to join a selected game
    // @param user selects a _gameId to play & submits a rating between 1 - 100 for the image
    function _joinGameWithEth(uint256 _gameId, uint256 _playerRating) internal nonReentrant {
        // Checks
        require(msg.value > 0, "Please send Eth to enter");
        require(msg.value >= gameEntryPriceInEth, "Please send correct amount of Eth to enter");

        // transfer any overpaid Eth to player
        if (msg.value > gameEntryPriceInEth) {
            uint256 refundAmount = msg.value - gameEntryPriceInEth;
            (bool sent,) = payable(msg.sender).call{value: refundAmount}("");
            require(sent, "Failed to refund overpaid Ether");
        }

        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating; // Map player address to their rating within the selected game
        games[_gameId].gameBalance += msg.value;

        // Interactions - none, Eth accepted into contract

        // emit event
        emit PlayerJoinedGameWithEth(msg.sender, _gameId, _playerRating);
    }

    // @notice allows new players to join a selected game using ERC20 tokens
    // @param players must pass in an amount of an allow-listed token along with their selected _gameId & image rating
    function _joinGameWithTokens(IERC20 _token, uint256 _amountOfToken, uint256 _gameId, uint256 _playerRating)
        internal
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
        require(_amountOfToken >= tokenEntryPrice, "Please send correct amount of tokens to enter");

        // transfer any overpaid token amount to player
        if (_amountOfToken > tokenEntryPrice) {
            uint256 refundAmountInTokens = _amountOfToken - tokenEntryPrice;
            _token.transfer(msg.sender, refundAmountInTokens);
        }

        require(_gameId > 0 && _gameId <= gameId, "Please select a game to enter");
        require(_playerRating > 0 && _playerRating < 101, "Please provide a rating of between 1 - 100");

        // Effects
        // Map player address to their rating within the selected game
        games[_gameId].playerAddressesToRatings[msg.sender] = _playerRating;

        // Interactions
        // transfer tokens from player to contract (EOA approval required beforehand)
        bool success = _token.transferFrom(msg.sender, address(this), _amountOfToken);
        if (success != true) {
            Error__TokenTransferFailed;
        }

        // emit event
        emit PlayerJoinedGameWithTokens(msg.sender, _gameId, _playerRating);
    }

    function endGame(uint256 _aiRating) public onlyAi {}

    function addTokenToAllowedList(IERC20 _token) public onlyOwner {
        gameTokensAllowedList.push(_token);
    }

    // =================
    // === MODIFIERS ===
    // =================

    modifier onlyAi() {
        require(msg.sender == ai, "Only the AI can call this function");
        _;
    }
}
