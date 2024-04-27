import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spotify_display/states/main_state.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  late final ValueNotifier<BluetoothLowEnergyState> state;
  late final ValueNotifier<bool> discovering;
  late final ValueNotifier<List<DiscoveredEventArgs>> discoveredEventArgs;
  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription discoveredSubscription;

  @override
  void initState() {
    super.initState();
    state = ValueNotifier(BluetoothLowEnergyState.unknown);
    discovering = ValueNotifier(false);
    discoveredEventArgs = ValueNotifier([]);
    stateChangedSubscription = CentralManager.instance.stateChanged.listen(
      (eventArgs) {
        state.value = eventArgs.state;
      },
    );
    discoveredSubscription = CentralManager.instance.discovered.listen(
      (eventArgs) {
        final items = discoveredEventArgs.value;
        final i = items.indexWhere(
          (item) => item.peripheral == eventArgs.peripheral,
        );
        if (i < 0) {
          discoveredEventArgs.value = [...items, eventArgs];
        } else {
          items[i] = eventArgs;
          discoveredEventArgs.value = [...items];
        }
      },
    );
    _initialize();
  }

  void _initialize() async {
    state.value = await CentralManager.instance.getState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: buildAppBar(context),
      body: buildBody(context),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF121212),
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Scanner',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        ValueListenableBuilder(
          valueListenable: state,
          builder: (context, state, child) {
            return ValueListenableBuilder(
              valueListenable: discovering,
              builder: (context, discovering, child) {
                return TextButton(
                  onPressed: state == BluetoothLowEnergyState.poweredOn
                      ? () async {
                          if (discovering) {
                            await stopDiscovery();
                          } else {
                            await startDiscovery();
                          }
                        }
                      : null,
                  child: Text(
                    discovering ? 'END' : 'BEGIN',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> startDiscovery() async {
    discoveredEventArgs.value = [];
    await CentralManager.instance.startDiscovery();
    discovering.value = true;
  }

  Future<void> stopDiscovery() async {
    await CentralManager.instance.stopDiscovery();
    discovering.value = false;
  }

  Widget buildBody(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: discoveredEventArgs,
      builder: (context, discoveredEventArgs, child) {
        // final items = discoveredEventArgs;
        final items = discoveredEventArgs
            .where((eventArgs) => eventArgs.advertisement.name != null)
            .toList();
        return ListView.separated(
          itemBuilder: (context, i) {
            final theme = Theme.of(context);
            final item = items[i];
            final uuid = item.peripheral.uuid;
            final rssi = item.rssi;
            final advertisement = item.advertisement;
            final name = advertisement.name;
            return ListTile(
              onTap: () async {
                final discovering = this.discovering.value;
                if (discovering) {
                  await stopDiscovery();
                }
                if (!mounted) {
                  throw UnimplementedError();
                }
                // Connect to the peripheral
                await CentralManager.instance.connect(item.peripheral);
                List<GattService> services =
                    await CentralManager.instance.discoverGATT(item.peripheral);
                GattService? service = services.firstWhere(
                  (service) =>
                      service.uuid ==
                      UUID.fromString('00007777-0000-1000-8000-00805f9b34fb'),
                );
                if (service != null) {
                  dynamic? characteristic = service.characteristics.firstWhere(
                    (characteristic) =>
                        characteristic.uuid ==
                        UUID.fromString('00008877-0000-1000-8000-00805f9b34fb'),
                  );

                  if (characteristic != null) {
                    Provider.of<MainState>(context, listen: false)
                        .setLedCharacteristic(characteristic);
                    Provider.of<MainState>(context, listen: false)
                        .sendCommand();
                  }
                }
                Navigator.pop(context, item);
              },
              title: Text(
                name ?? 'N/A',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '$uuid',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // RssiWidget(rssi),
                  Text(
                    '$rssi',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (context, i) {
            return const Divider(
              height: 0.0,
            );
          },
          itemCount: items.length,
        );
      },
    );
  }
}
