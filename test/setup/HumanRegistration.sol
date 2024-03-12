// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract HumanRegistration is Test {
    // Constants
    uint256 public immutable N;

    // State variables

    // forgefmt: disable-next-line
    string[50] public avatars = ["Alice", "Bob", "Charlie", "David", "Eve", "Frank", "Grace", "Hank", "Ivy", "Jack", "Kathy", "Liam", "Mia", "Noah", "Olivia", "Parker", "Quinn", "Ruby", "Steve", "Tina", "Umar", "Violet", "Wes", "Xena", "Yale", "Zara", "Asher", "Bella", "Cody", "Daisy", "Edward", "Fiona", "George", "Holly", "Ian", "Jenna", "Kevin", "Luna", "Mason", "Nina", "Oscar", "Piper", "Quincy", "Rosa", "Sam", "Troy", "Una", "Victor", "Wendy", "Xander"];

    address[] public addresses;
    address[] public sortedAddresses;
    uint16[] public permutationMap;
    uint16[] public lookupMap;

    // Public functions

    constructor(uint16 _n) {
        require(_n <= 50, "N must be less than or equal to 50");
        N = _n;
        addresses = new address[](N);
        sortedAddresses = new address[](N);
        permutationMap = new uint16[](N);
        lookupMap = new uint16[](N);
        for (uint256 i = 0; i < N; i++) {
            addresses[i] = makeAddr(avatars[i]);
        }
        sortAddressesWithPermutationMap();
    }

    // Private functions

    /**
     * @dev Sorts an array of addresses in ascending order using Bubble Sort
     *      and returns the permutation map. This is not meant to be an efficient sort,
     *      rather the simplest implementation for transparancy of the test.
     */
    function sortAddressesWithPermutationMap() private {
        uint256 length = addresses.length;
        sortedAddresses = addresses;

        // Initialize the permutation map with original indices
        for (uint16 i = 0; i < length; i++) {
            permutationMap[i] = i;
        }

        // Bubble sort the array and the permutation map
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (sortedAddresses[j] > sortedAddresses[j + 1]) {
                    // Swap elements in the address array
                    (sortedAddresses[j], sortedAddresses[j + 1]) = (sortedAddresses[j + 1], sortedAddresses[j]);
                    // Swap corresponding elements in the permutation map
                    (permutationMap[j], permutationMap[j + 1]) = (permutationMap[j + 1], permutationMap[j]);
                }
            }
        }

        // Create a lookup map for the sorted addresses
        for (uint16 i = 0; i < length; i++) {
            lookupMap[permutationMap[i]] = i;
        }
    }
}
