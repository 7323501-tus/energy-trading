// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;
contract Trading6 {
    address public owner;
    uint256 public RecalculateCount;
    uint256 ci = 0;                 // consumerListCount                    
    uint256 pi = 0;                 // prosumerListCount                          
    uint256 ti = 1;                 // timeCount (初期値 = 1 ) 
    uint256 ContractPrice = 0;
    uint256 public tradeCount = 0;
    uint256 public totalConsumerSum = 0;
    uint256 public totalProsumerSum = 0;   

    // tradeVolumeごとの回数をカウントするための配列
    uint[26] public tradeVolumeCount; // tradeVolumeが0~25を対象 (インデックス0は使わない)                   
 
    event DicisionContractPrice(uint256 ContractPrice);
    event TradeExecuted(uint consumerNumber, uint prosumerNumber, uint256 tradeVolume);
    event TradeVolumeCounted(uint volume, uint count); // tradeVolumeごとの回数を出力するイベント

    modifier onlyOwner() {
        require(owner == msg.sender, "only owner!");
        _;
    }
    address consumeraddress;
    address prosumeraddress;
    struct Consumer {
        address consumer;           // consumerのHash値
        uint256 number;             // consumer id
        uint256 kwh;                // consumerが欲しい電力量
        uint256 time;               // consumerが板に登録した時刻
        uint256 value;              // consumerが購入する金額
        uint256 sum;                // consumerが保有する電力量
        bool traded;                // 取引済みかのフラグ 
    }
    mapping(address => uint) public confirmConsumer;
    Consumer[] public consumerList;
    Prosumer[] public prosumerList;
    struct Prosumer {
        address prosumer;
        uint256 number;             
        uint256 kwh;
        uint256 time;
        uint256 value;
        uint256 sum;
        bool traded;                 
    }
    mapping(address => uint) public confirmProsumer;
    constructor() {
        RecalculateCount = 0;
        owner = msg.sender;
        consumeraddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        prosumeraddress = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    }
    /////////////////////////////////////////////////
    //Consumer Counting-sort by time
    function countingSortConsumers() public {
        // 配列の初期化
        uint256 maxTime = 30;
        uint256[] memory count = new uint256[](maxTime + 1);
        Consumer[] memory sorted = new Consumer[](consumerList.length);
        // 各timeの出現回数カウント
        for (uint i = 0; i < consumerList.length; i++) {
            count[consumerList[i].time]++;
        }
        // 累積カウント計算
        for (uint i = 1; i <= maxTime; i++) {
            count[i] += count[i - 1];
        }
        // 元配列を使用して、ソートされた配列構築
        for (int i = int(consumerList.length) - 1; i >= 0; i--) {
            Consumer storage consumer = consumerList[uint(i)];
            sorted[count[consumer.time] - 1] = consumer;
            count[consumer.time]--;
        }
        // ソートしたデータを元配列にコピー
        for (uint i = 0; i < consumerList.length; i++) {
            consumerList[i] = sorted[i];
        }
    }

    // Prosumer Counting-sort by time
    function countingSortProsumers() public {
        uint256 maxTime = 30;
        uint256[] memory count = new uint256[](maxTime + 1);
        Prosumer[] memory sorted = new Prosumer[](prosumerList.length);

        for (uint i = 0; i < prosumerList.length; i++) {
            count[prosumerList[i].time]++;
        }
        for (uint i = 1; i <= maxTime; i++) {
            count[i] += count[i - 1];
        }
        for (int i = int(prosumerList.length) - 1; i >= 0; i--) {
            Prosumer storage prosumer = prosumerList[uint(i)];
            sorted[count[prosumer.time] - 1] = prosumer;
            count[prosumer.time]--;
        }
        for (uint i = 0; i < prosumerList.length; i++) {
            prosumerList[i] = sorted[i];
        }
    }
//binary-search
    function findStartIndex(Consumer[] storage list, uint256 time) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = list.length;
            while (low < high) {
                uint256 mid = low + (high - low) / 2;
                if (list[mid].time < time) {
                    low = mid + 1;
                } else {
                    high = mid;
                }
            }
        return low;
    }
    function findStartIndex(Prosumer[] storage list, uint256 time) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = list.length;
            while (low < high) {
                uint256 mid = low + (high - low) / 2;
                if (list[mid].time < time) {
                    low = mid + 1;
                } else {
                    high = mid;
                }
            }
        return low;
    }



    ///////////////////////////////////////////////////
    //Agreement by ct-trade
    function Agreement() public onlyOwner  {
        require(prosumerList.length > 0 && consumerList.length > 0, "Lists cannot be empty!");

        while (ti <= 30) {
            uint256 consumerStart = findStartIndex(consumerList, ti);
            uint256 prosumerStart = findStartIndex(prosumerList, ti);

            for (uint256 i = consumerStart; i < consumerList.length && consumerList[i].time == ti; i++) {
                Consumer storage consumer = consumerList[i];
                if (consumer.traded || consumer.kwh == 0 || consumer.time > ti) continue;

                for (uint256 j = prosumerStart; j < prosumerList.length && prosumerList[j].time == ti; j++) {
                    Prosumer storage prosumer = prosumerList[j];
                    if (prosumer.traded || prosumer.sum == 0 || prosumer.time > ti) continue;

                    if (prosumer.value <= consumer.value) {
                        uint256 tradeVolume = consumer.kwh < prosumer.sum ? consumer.kwh : prosumer.sum;
                        consumer.kwh -= tradeVolume;
                        consumer.sum += tradeVolume;
                        prosumer.sum -= tradeVolume;
                        tradeCount++;
                        tradeCount++;

                        if (consumer.kwh == 0) {
                            consumer.traded = true;
                        }
                        if (prosumer.sum == 0) {
                            prosumer.traded = true;
                        }
                        if (consumer.kwh == 0 || prosumer.sum == 0) {
                            break;
                        }
                    }
                }
            }
            ti++;
        }

        for (uint256 i = 0; i < consumerList.length; i++) {
            totalConsumerSum += consumerList[i].sum;
        }

    // 合計消費量と供給量を計算
    calculateTotals();

    // tradeVolumeごとの回数を出力する
    outputTradeVolumeCounts();
}

// 合計消費量と供給量を計算する関数
function calculateTotals() internal {
    uint256 consumerSum = 0;
    uint256 prosumerSum = 0;

    for (uint256 i = 0; i < consumerList.length; i++) {
        consumerSum += consumerList[i].sum;
    }
    totalConsumerSum = consumerSum;

    for (uint256 i = 0; i < prosumerList.length; i++) {
        prosumerSum += prosumerList[i].sum;
    }
    totalProsumerSum = prosumerSum;
}

// tradeVolumeごとの回数を出力する関数
function outputTradeVolumeCounts() internal {
    for (uint i = 1; i <= 25; i++) {
        emit TradeVolumeCounted(i, tradeVolumeCount[i]);
    }
}


    ////////////////////////////////////////////////////
    //Create Consumer by Gaussian distribution
    function C100ConsumerData(uint steps) public {
        Consumer[] memory consumerresult = new Consumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.number, loop, idx)));
                uint time = (blockHash % 30) + 1;
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Consumer memory newconsumer = Consumer(consumeraddress, number, kwh, time, value, 0, false); 
                consumerresult[sum + idx] = newconsumer;
            }
            sum += endpoint[loop];
        }

        for (uint i = 0; i < consumerresult.length; i++) {
            consumerList.push(consumerresult[i]);
        }
    }

    //Create Prosumer by Gaussian distribution
    function C100ProsumerData(uint steps) public {
        Prosumer[] memory prosumerresult = new Prosumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.timestamp, block.number, loop, idx)));
                uint time = (blockHash % 30) + 1;
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Prosumer memory newprosumer = Prosumer(prosumeraddress, number, time, kwh, value, kwh, false); 
                prosumerresult[sum + idx] = newprosumer;
            }
            sum += endpoint[loop];
        }

        for (uint j = 0; j < prosumerresult.length; j++) {
            prosumerList.push(prosumerresult[j]);
        }
    }

    //Create Consumer by Gaussian distribution
    function C10ConsumerData(uint steps) public {
        Consumer[] memory consumerresult = new Consumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10,steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.number, loop, idx)));
                uint time = (blockHash % 30) + 1;
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Consumer memory newconsumer = Consumer(consumeraddress, number, kwh, time, value, 0, false); 
                consumerresult[sum + idx] = newconsumer;
            }
            sum += endpoint[loop];
        }

        for (uint i = 0; i < consumerresult.length; i++) {
            consumerList.push(consumerresult[i]);
        }
    }

    //Create Prosumer by Gaussian distribution
    function C10ProsumerData(uint steps) public {
        Prosumer[] memory prosumerresult = new Prosumer[](steps);
        uint[10] memory endpoint = [steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10, steps*1/10,steps*1/10, steps*1/10, steps*1/10, steps*1/10];
        uint8[10] memory endpointdata = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

        uint sum = 0;
        uint number = 1; 
        for (uint loop = 0; loop < endpointdata.length; loop++) {
            for (uint idx = 0; idx < endpoint[loop]; idx++) {
                uint blockHash = uint(keccak256(abi.encodePacked(block.timestamp, block.number, loop, idx)));
                uint time = (blockHash % 30) + 1;
                uint kwh = 5 + blockHash % 20;
                uint value = endpointdata[endpoint.length - loop - 1];

                Prosumer memory newprosumer = Prosumer(prosumeraddress, number, time, kwh, value, kwh, false); 
                prosumerresult[sum + idx] = newprosumer;
            }
            sum += endpoint[loop];
        }

        for (uint j = 0; j < prosumerresult.length; j++) {
            prosumerList.push(prosumerresult[j]);
        }
    }
}