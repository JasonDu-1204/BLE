
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ble_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleManager>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 调试助手'),
        actions: [
          Consumer<BleManager>(
            builder: (context, manager, _) {
              return IconButton(
                icon: Icon(manager.isScanning ? Icons.stop : Icons.search),
                onPressed: manager.isScanning ? manager.stopScan : manager.startScan,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<BleManager>(
            builder: (context, manager, _) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("状态: ${manager.status}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (manager.connectedDevice != null)
                      ElevatedButton(
                        onPressed: manager.disconnect,
                        child: const Text("断开"),
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            flex: 2,
            child: Consumer<BleManager>(
              builder: (context, manager, _) {
                if (manager.connectedDevice != null) {
                  return _buildConnectedView(manager);
                } else {
                  return _buildDeviceList(manager);
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Consumer<BleManager>(
                builder: (context, manager, _) {
                  return SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      manager.log,
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          if (context.watch<BleManager>().connectedDevice != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: const InputDecoration(
                        labelText: "十六进制数据 (如: 01 02)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      context.read<BleManager>().sendData(_hexController.text);
                      _hexController.clear();
                    },
                    child: const Text("发送"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BleManager manager) {
    if (manager.devices.isEmpty) {
      return const Center(child: Text("点击搜索按钮扫描设备"));
    }
    return ListView.builder(
      itemCount: manager.devices.length,
      itemBuilder: (context, index) {
        final device = manager.devices[index];
        return ListTile(
          title: Text(device.name.isNotEmpty ? device.name : "未知设备"),
          subtitle: Text("${device.id}\nRSSI: ${device.rssi}"),
          trailing: const Icon(Icons.bluetooth),
          onTap: () => manager.connectToDevice(device),
        );
      },
    );
  }

  Widget _buildConnectedView(BleManager manager) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("已连接设备详情:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("名称: ${manager.connectedDevice?.name ?? 'Unknown'}"),
          Text("ID: ${manager.connectedDevice?.id ?? ''}"),
          const SizedBox(height: 20),
          const Text("可用特征值:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (manager.writeChar != null)
            Text("写特征: ${manager.writeChar!.characteristicId.toString()}"),
          if (manager.readChar != null)
            Text("读/通知特征: ${manager.readChar!.characteristicId.toString()}"),
        ],
      ),
    );
  }
}
