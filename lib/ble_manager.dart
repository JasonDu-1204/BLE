
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleManager extends ChangeNotifier {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  
  List<DiscoveredDevice> _devices = [];
  DiscoveredDevice? _connectedDevice;
  QualifiedCharacteristic? _writeCharacteristic;
  QualifiedCharacteristic? _readCharacteristic;
  StreamSubscription<List<int>>? _subscription;
  
  String _status = "未初始化";
  String _log = "";
  bool _isScanning = false;

  List<DiscoveredDevice> get devices => _devices;
  DiscoveredDevice? get connectedDevice => _connectedDevice;
  String get status => _status;
  String get log => _log;
  bool get isScanning => _isScanning;
  QualifiedCharacteristic? get writeChar => _writeCharacteristic;
  QualifiedCharacteristic? get readChar => _readCharacteristic;

  void _addLog(String msg) {
    _log = "$msg\n$_log";
    notifyListeners();
  }

  Future<void> initialize() async {
    _status = "初始化中...";
    notifyListeners();
    try {
      await _ble.initialize();
      _status = "蓝牙就绪";
      _addLog("BLE 初始化成功");
    } catch (e) {
      _status = "初始化失败: $e";
      _addLog("BLE 初始化失败: $e");
    }
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    _devices.clear();
    _isScanning = true;
    _status = "正在扫描...";
    _addLog("开始扫描附近设备");
    notifyListeners();

    _ble.scanForDevices(withServices: []).listen((device) {
      final isKnown = _devices.any((d) => d.id == device.id);
      if (!isKnown && device.name.isNotEmpty) {
        _devices.add(device);
        notifyListeners();
      }
    }, onError: (e) {
      _addLog("扫描错误: $e");
      stopScan();
    });
  }

  void stopScan() {
    _isScanning = false;
    _status = "扫描停止";
    _ble.stopScan();
    notifyListeners();
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    stopScan();
    _status = "正在连接 ${device.name}...";
    _addLog("尝试连接: ${device.name} (${device.id})");
    notifyListeners();

    try {
      _connectedDevice = await _ble.connectToDevice(id: device.id).first;
      _status = "已连接: ${device.name}";
      _addLog("连接成功");
      await _discoverServices(_connectedDevice!.id);
    } catch (e) {
      _status = "连接失败: $e";
      _addLog("连接失败: $e");
      _connectedDevice = null;
    }
    notifyListeners();
  }

  Future<void> _discoverServices(String deviceId) async {
    try {
      final services = await _ble.discoverServices(deviceId);
      _addLog("发现 ${services.length} 个服务");
      
      for (var service in services) {
        for (var char in service.characteristics) {
          if (_writeCharacteristic == null && 
              (char.properties.write || char.properties.writeWithoutResponse)) {
            _writeCharacteristic = QualifiedCharacteristic(
              serviceId: service.serviceId,
              characteristicId: char.characteristicId,
              deviceId: deviceId,
            );
          }
          
          if (_readCharacteristic == null && 
              (char.properties.read || char.properties.notify)) {
            _readCharacteristic = QualifiedCharacteristic(
              serviceId: service.serviceId,
              characteristicId: char.characteristicId,
              deviceId: deviceId,
            );
            
            if (char.properties.notify) {
              _subscribeToCharacteristic(_readCharacteristic!);
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      _addLog("服务发现失败: $e");
    }
  }

  void _subscribeToCharacteristic(QualifiedCharacteristic char) {
    _subscription?.cancel();
    _subscription = _ble.subscribeToCharacteristic(char).listen((data) {
      final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      _addLog("收到通知数据: $hex");
    }, onError: (e) {
      _addLog("订阅错误: $e");
    });
  }

  Future<void> sendData(String hexString) async {
    if (_writeCharacteristic == null) {
      _addLog("错误: 未找到可写特征值");
      return;
    }
    try {
      final bytes = _hexToBytes(hexString);
      await _ble.writeCharacteristicWithResponse(
        _writeCharacteristic!,
        value: bytes,
      );
      _addLog("发送成功: $hexString");
    } catch (e) {
      _addLog("发送失败: $e");
    }
  }

  Uint8List _hexToBytes(String hex) {
    hex = hex.replaceAll(RegExp(r'\s+'), '');
    if (hex.length % 2 != 0) hex = '0$hex';
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _ble.disconnectDevice(_connectedDevice!.id);
      _subscription?.cancel();
      _connectedDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
      _status = "已断开";
      _addLog("设备已断开");
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ble.deinitialize();
    super.dispose();
  }
}
