import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer/thermal_printer.dart' as thermal;

import 'product_models.dart';
import 'product_storage.dart';
import 'order_ticket_models.dart';
import 'order_ticket_storage.dart';
import 'receipt_builder.dart';
import 'receipt_models.dart';
import 'transaction_models.dart';
import 'transaction_storage.dart';

void main() {
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Bluetooth POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PosHomePage(),
    );
  }
}

class PosHomePage extends StatefulWidget {
  const PosHomePage({super.key});

  @override
  State<PosHomePage> createState() => _PosHomePageState();
}

class _PosHomePageState extends State<PosHomePage> with WidgetsBindingObserver {
  static const List<String> _paymentMethods = ['Cash', 'QRIS', 'Transfer'];
  static const List<String> _productCategories = [
    'Drinks',
    'Food',
    'Snacks',
  ];
  static const _logoAssetPath = 'assets/images/store_logo.png';
  static const _thermalLogoScaleFactor = 0.125;
  static const _logoPreviewHeight = 36.0;
  static const _storeNameKey = 'receipt_store_name';
  static const _storeAddressKey = 'receipt_store_address';
  static const _bookingWhatsappKey = 'receipt_booking_whatsapp';
  static const _wifiNameKey = 'receipt_wifi_name';
  static const _wifiPasswordKey = 'receipt_wifi_password';
  static const _syncCsvHistoryKey = 'pos_sync_csv_history';
  static const _orderSequenceDateKey = 'pos_order_sequence_date';
  static const _orderSequenceValueKey = 'pos_order_sequence_value';
  static const _promoConfigsKey = 'pos_promo_configs';
  static const _defaultCatalogAssetPath =
      'assets/data/default_menu_catalog.txt';
  static const _printerModeKey = 'printer_connection_mode';
  static const _invoicePrinterModeKey = 'invoice_printer_connection_mode';
  static const _labelPrinterModeKey = 'label_printer_connection_mode';

  final _productNameController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _catalogSearchController = TextEditingController();
  final _saleQtyController = TextEditingController(text: '1');
  final _saleItemNoteController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _orderNumberController = TextEditingController();
  final _storeNameController = TextEditingController(text: 'Kreasi Positif');
  final _storeAddressController = TextEditingController(
    text: 'Your store address',
  );
  final _bookingWhatsappController = TextEditingController();
  final _wifiNameController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _promoDiscountPercentController = TextEditingController(text: '10');
  final _productStorage = ProductStorage();
  final _transactionStorage = TransactionStorage();
  final _orderTicketStorage = OrderTicketStorage();
  final _thermalPrinterManager = thermal.PrinterManager.instance;

  // Legacy single-printer state (kept for backward compatibility)
  List<BluetoothInfo> _pairedDevices = [];
  BluetoothInfo? _selectedPrinter;
  List<thermal.PrinterDevice> _usbDevices = [];
  thermal.PrinterDevice? _selectedUsbPrinter;
  bool _isPrinterConnected = false;
  bool _isUsbPrinterConnected = false;
  bool _usbNeedsRecoveryAfterResume = false;
  _PrinterConnectionMode _printerConnectionMode =
      _PrinterConnectionMode.bluetooth;

  // Invoice printer state
  List<BluetoothInfo> _invoicePairedDevices = [];
  BluetoothInfo? _invoiceSelectedPrinter;
  List<thermal.PrinterDevice> _invoiceUsbDevices = [];
  thermal.PrinterDevice? _invoiceSelectedUsbPrinter;
  bool _isInvoicePrinterConnected = false;
  bool _isInvoiceUsbPrinterConnected = false;
  bool _invoiceUsbNeedsRecoveryAfterResume = false;
  _PrinterConnectionMode _invoicePrinterConnectionMode =
      _PrinterConnectionMode.bluetooth;

  // Label printer state
  List<BluetoothInfo> _labelPairedDevices = [];
  BluetoothInfo? _labelSelectedPrinter;
  List<thermal.PrinterDevice> _labelUsbDevices = [];
  thermal.PrinterDevice? _labelSelectedUsbPrinter;
  bool _isLabelPrinterConnected = false;
  bool _isLabelUsbPrinterConnected = false;
  bool _labelUsbNeedsRecoveryAfterResume = false;
  _PrinterConnectionMode _labelPrinterConnectionMode =
      _PrinterConnectionMode.bluetooth;

  // Shared USB scanning state (reused for both invoice and label scanning)
  bool _isUsbScanInProgress = false;
  StreamSubscription<thermal.PrinterDevice>? _usbDiscoverySubscription;
  DateTime? _lastUsbScanAt;
  String? _lastUsbDiscoveryError;
  DateTime? _lastUsbConnectAt;
  String? _lastUsbConnectError;
  DateTime? _lastUsbPrintAt;
  bool? _lastUsbPrintSuccess;
  String? _lastUsbPrintError;

  List<Product> _catalogProducts = [];
  Product? _selectedCatalogProduct;
  final List<ReceiptItem> _items = [];
  List<_PromoConfig> _promoConfigs = [];
  List<OrderTicket> _incomingOrders = [];
  List<PosTransaction> _transactions = [];
  List<String> _syncCsvHistory = [];
  bool _isBluetoothPermissionGranted = false;
  PaperSize _selectedPaperSize = PaperSize.mm58;
  String _selectedPaymentMethod = 'Cash';
  String _selectedProductCategory = 'Drinks';
  String _selectedPromoCategory = 'Drinks';
  String _catalogSearchQuery = '';
  _PromoType _promoFormType = _PromoType.percentageProduct;
  String? _promoFormProductId;
  String? _selectedPromoConfigId;

  int _currentTabIndex = 0;

  _PricingSummary get _currentPricingSummary =>
      _calculatePricingSummary(_items, promo: _selectedPromoConfig);
  _PromoConfig? get _selectedPromoConfig {
    final selectedId = _selectedPromoConfigId;
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final promo in _promoConfigs) {
      if (promo.id == selectedId) return promo;
    }
    return null;
  }

  String get _selectedPromoDropdownValue {
    final selected = _selectedPromoConfig;
    return selected == null ? 'none' : selected.id;
  }

  List<Product> get _filteredCatalogProducts {
    final query = _catalogSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _catalogProducts;

    return _catalogProducts.where((product) {
      final productName = product.name.toLowerCase();
      final productCategory = product.category.toLowerCase();
      final price = product.price.toString();
      return productName.contains(query) ||
          productCategory.contains(query) ||
          price.contains(query);
    }).toList();
  }

  int get _pendingSyncCount => _transactions.where((t) => !t.synced).length;
  String get _resolvedStoreName => _storeNameController.text.trim().isEmpty
      ? 'Kreasi Positif'
      : _storeNameController.text.trim();

  // Helper getters for dual-printer state access
  BluetoothInfo? _selectedPrinterForType(_PrinterType printerType) =>
      printerType == _PrinterType.invoice
          ? _invoiceSelectedPrinter
          : _labelSelectedPrinter;

  thermal.PrinterDevice? _selectedUsbPrinterForType(_PrinterType printerType) =>
      printerType == _PrinterType.invoice
          ? _invoiceSelectedUsbPrinter
          : _labelSelectedUsbPrinter;

  _PrinterConnectionMode _printerModeForType(_PrinterType printerType) =>
      printerType == _PrinterType.invoice
          ? _invoicePrinterConnectionMode
          : _labelPrinterConnectionMode;

  bool _isBtConnectedForType(_PrinterType printerType) =>
      printerType == _PrinterType.invoice
          ? _isInvoicePrinterConnected
          : _isLabelPrinterConnected;

  bool _isUsbConnectedForType(_PrinterType printerType) =>
      printerType == _PrinterType.invoice
          ? _isInvoiceUsbPrinterConnected
          : _isLabelUsbPrinterConnected;

  List<BluetoothInfo> _btDevicesForType(_PrinterType printerType) =>
      printerType == _PrinterType.invoice
          ? _invoicePairedDevices
          : _labelPairedDevices;

  List<thermal.PrinterDevice> _usbDevicesForType(_PrinterType printerType) =>
      printerType == _PrinterType.invoice
          ? _invoiceUsbDevices
          : _labelUsbDevices;

  void _setSelectedBtPrinter(_PrinterType printerType, BluetoothInfo? printer) {
    if (printerType == _PrinterType.invoice) {
      _invoiceSelectedPrinter = printer;
    } else {
      _labelSelectedPrinter = printer;
    }
  }

  void _setSelectedUsbPrinter(
      _PrinterType printerType, thermal.PrinterDevice? printer) {
    if (printerType == _PrinterType.invoice) {
      _invoiceSelectedUsbPrinter = printer;
    } else {
      _labelSelectedUsbPrinter = printer;
    }
  }

  void _setBtConnected(_PrinterType printerType, bool value) {
    if (printerType == _PrinterType.invoice) {
      _isInvoicePrinterConnected = value;
    } else {
      _isLabelPrinterConnected = value;
    }
  }

  void _setUsbConnected(_PrinterType printerType, bool value) {
    if (printerType == _PrinterType.invoice) {
      _isInvoiceUsbPrinterConnected = value;
    } else {
      _isLabelUsbPrinterConnected = value;
    }
  }

  void _setPrinterMode(_PrinterType printerType, _PrinterConnectionMode mode) {
    if (printerType == _PrinterType.invoice) {
      _invoicePrinterConnectionMode = mode;
    } else {
      _labelPrinterConnectionMode = mode;
    }
  }

  void _setUsbNeedsRecovery(_PrinterType printerType, bool value) {
    if (printerType == _PrinterType.invoice) {
      _invoiceUsbNeedsRecoveryAfterResume = value;
    } else {
      _labelUsbNeedsRecoveryAfterResume = value;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePrinterFlow();
    _loadReceiptSettings();
    _loadCatalogProducts();
    _loadTransactions();
    _loadIncomingOrders();
    _loadSyncCsvHistory();
    _loadPromoConfigs();
    _ensureOrderNumberInitialized();
  }

  String _currentDateStamp() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  Future<void> _ensureOrderNumberInitialized() async {
    if (_orderNumberController.text.trim().isNotEmpty) return;
    await _generateNextOrderNumber();
  }

  Future<void> _generateNextOrderNumber() async {
    final preferences = await SharedPreferences.getInstance();
    final dateStamp = _currentDateStamp();
    final savedDate = preferences.getString(_orderSequenceDateKey);
    final savedSequence = preferences.getInt(_orderSequenceValueKey) ?? 0;

    final nextSequence = savedDate == dateStamp ? savedSequence + 1 : 1;

    await preferences.setString(_orderSequenceDateKey, dateStamp);
    await preferences.setInt(_orderSequenceValueKey, nextSequence);

    if (!mounted) return;
    setState(() {
      _orderNumberController.text =
          '$dateStamp-${nextSequence.toString().padLeft(4, '0')}';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _productNameController.dispose();
    _productPriceController.dispose();
    _catalogSearchController.dispose();
    _saleQtyController.dispose();
    _saleItemNoteController.dispose();
    _customerNameController.dispose();
    _orderNumberController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _bookingWhatsappController.dispose();
    _wifiNameController.dispose();
    _wifiPasswordController.dispose();
    _promoDiscountPercentController.dispose();
    _usbDiscoverySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;

    if (_printerConnectionMode == _PrinterConnectionMode.usb) {
      setState(() {
        _isUsbPrinterConnected = false;
        _usbNeedsRecoveryAfterResume = true;
      });
      return;
    }

    setState(() {
      _isPrinterConnected = false;
    });
  }

  int get _lineWidth => _selectedPaperSize == PaperSize.mm80 ? 48 : 32;

  Future<void> _initializePrinterFlow() async {
    await _loadPrinterConnectionMode();
    if (_printerConnectionMode == _PrinterConnectionMode.bluetooth) {
      await _initializeBluetoothFlow();
      return;
    }
    await _refreshUsbPrinters();
  }

  Future<void> _loadPrinterConnectionMode() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_printerModeKey) ?? '';
    final resolved = saved == _PrinterConnectionMode.usb.code
        ? _PrinterConnectionMode.usb
        : _PrinterConnectionMode.bluetooth;

    if (!mounted) return;
    setState(() {
      _printerConnectionMode = resolved;
    });
  }

  Future<void> _savePrinterConnectionMode(_PrinterConnectionMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_printerModeKey, mode.code);
  }

  Future<void> _setPrinterConnectionMode(_PrinterConnectionMode mode) async {
    if (_printerConnectionMode == mode) return;

    if (mode == _PrinterConnectionMode.bluetooth) {
      await _stopUsbDiscovery();
      await _disconnectUsbPrinter(showMessage: false);
    } else {
      await _disconnectPrinterSilently();
    }

    if (!mounted) return;
    setState(() {
      _printerConnectionMode = mode;
      if (mode == _PrinterConnectionMode.bluetooth) {
        _usbNeedsRecoveryAfterResume = false;
      }
    });
    await _savePrinterConnectionMode(mode);

    if (mode == _PrinterConnectionMode.bluetooth) {
      await _initializeBluetoothFlow();
      _showMessage('Printer mode switched to Bluetooth.');
      return;
    }

    await _refreshUsbPrinters();
    _showMessage('Printer mode switched to USB OTG.');
  }

  Future<void> _initializeBluetoothFlow() async {
    final granted = await _ensureBluetoothPermission();
    if (!granted) {
      _showMessage(
        'Nearby devices permission is required for Bluetooth printer access.',
      );
      return;
    }
    await _loadPairedPrinters();
  }

  Future<bool> _ensureBluetoothPermission() async {
    final connectStatus = await Permission.bluetoothConnect.status;
    final scanStatus = await Permission.bluetoothScan.status;

    if (connectStatus.isGranted && scanStatus.isGranted) {
      if (mounted) {
        setState(() => _isBluetoothPermissionGranted = true);
      }
      return true;
    }

    final connectRequest = await Permission.bluetoothConnect.request();
    final scanRequest = await Permission.bluetoothScan.request();
    await Permission.locationWhenInUse.request();

    final granted = connectRequest.isGranted && scanRequest.isGranted;

    if (mounted) {
      setState(() => _isBluetoothPermissionGranted = granted);
    }

    if (!granted &&
        (connectRequest.isPermanentlyDenied ||
            scanRequest.isPermanentlyDenied)) {
      await openAppSettings();
    }

    return granted;
  }

  Future<void> _loadPairedPrinters({bool showMessage = true}) async {
    final granted = await _ensureBluetoothPermission();
    if (!granted) {
      if (showMessage) {
        _showMessage(
            'Enable Nearby devices permission, then refresh printers.');
      }
      return;
    }

    final connected = await PrintBluetoothThermal.connectionStatus;
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    final resolvedSelection =
        _resolveBluetoothSelection(_selectedPrinter, devices);

    if (!mounted) return;
    setState(() {
      _pairedDevices = devices;
      _isPrinterConnected = connected;
      _selectedPrinter = resolvedSelection;
    });
  }

  Future<bool> _tryConnectBluetoothWithRetries({
    int attempts = 3,
  }) async {
    var selectedPrinter = _selectedPrinter;
    if (selectedPrinter == null) {
      await _loadPairedPrinters(showMessage: false);
      selectedPrinter = _selectedPrinter;
    }
    if (selectedPrinter == null) return false;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}

      if (attempt > 0) {
        await _loadPairedPrinters(showMessage: false);
        final refreshed = _pairedDevices.where(
          (device) => device.macAdress == selectedPrinter!.macAdress,
        );
        if (refreshed.isNotEmpty) {
          selectedPrinter = refreshed.first;
          if (mounted) {
            setState(() {
              _selectedPrinter = selectedPrinter;
            });
          }
        }
      }

      try {
        final connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: selectedPrinter!.macAdress,
        );
        if (mounted) {
          setState(() {
            _isPrinterConnected = connected;
          });
        }
        if (connected) return true;
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (mounted) {
      setState(() {
        _isPrinterConnected = false;
      });
    }
    return false;
  }

  Future<void> _connectPrinter() async {
    if (!_isBluetoothPermissionGranted) {
      final granted = await _ensureBluetoothPermission();
      if (!granted) {
        _showMessage('Bluetooth permission not granted.');
        return;
      }
    }

    if (_selectedPrinter == null) {
      _showMessage('Select a paired printer first.');
      return;
    }

    final connected = await _tryConnectBluetoothWithRetries();
    if (connected) {
      _showMessage('Connected to ${_selectedPrinter!.name}.');
    } else {
      _showMessage(
        'Failed to connect Bluetooth printer. If this happens after idle, wake the printer and retry.',
      );
    }
  }

  Future<void> _disconnectPrinter() async {
    await PrintBluetoothThermal.disconnect;
    if (!mounted) return;
    setState(() => _isPrinterConnected = false);
    _showMessage('Printer disconnected.');
  }

  Future<void> _disconnectPrinterSilently() async {
    await PrintBluetoothThermal.disconnect;
    if (!mounted) return;
    setState(() => _isPrinterConnected = false);
  }

  String _usbDeviceKey(thermal.PrinterDevice device) {
    final name = device.name;
    final vendorId = device.vendorId?.toString() ?? '';
    final productId = device.productId?.toString() ?? '';
    final address = device.address ?? '';
    return '$name|$vendorId|$productId|$address';
  }

  BluetoothInfo? _resolveBluetoothSelection(
    BluetoothInfo? preferred,
    List<BluetoothInfo> devices,
  ) {
    if (devices.isEmpty) return null;
    if (preferred == null) return devices.first;

    for (final device in devices) {
      if (device.macAdress == preferred.macAdress) {
        return device;
      }
    }

    return devices.first;
  }

  thermal.PrinterDevice? _resolveUsbSelection(
    thermal.PrinterDevice? preferred,
    List<thermal.PrinterDevice> devices,
  ) {
    if (devices.isEmpty) return null;
    if (preferred == null) return devices.first;

    final preferredKey = _usbDeviceKey(preferred);
    for (final device in devices) {
      if (_usbDeviceKey(device) == preferredKey) {
        return device;
      }
    }

    return devices.first;
  }

  String _formatDebugTime(DateTime? value) {
    if (value == null) return '-';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _truncateDebugText(String text, {int maxLength = 80}) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }

  String _sanitizePrinterText(String value) {
    if (value.isEmpty) return value;

    final normalized = value
        .replaceAll('…', '...')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('•', '-')
        .replaceAll('\t', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');

    final buffer = StringBuffer();
    for (final rune in normalized.runes) {
      if (rune == 10 || rune == 13 || rune == 9) {
        buffer.write(' ');
        continue;
      }

      if (rune >= 32 && rune <= 126) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write('?');
      }
    }

    return buffer.toString();
  }

  Future<void> _stopUsbDiscovery() async {
    await _usbDiscoverySubscription?.cancel();
    _usbDiscoverySubscription = null;
    if (!mounted) return;
    setState(() {
      _isUsbScanInProgress = false;
    });
  }

  Future<void> _refreshUsbPrinters({bool showEmptyMessage = true}) async {
    await _stopUsbDiscovery();
    if (!mounted) return;

    final existingDevices = List<thermal.PrinterDevice>.from(_usbDevices);

    setState(() {
      _isUsbScanInProgress = true;
      _isUsbPrinterConnected = false;
      _lastUsbScanAt = DateTime.now();
      _lastUsbDiscoveryError = null;
    });

    final discoveredKeys = <String>{
      ...existingDevices.map(_usbDeviceKey),
    };
    final discoveredDevices = <thermal.PrinterDevice>[...existingDevices];

    _usbDiscoverySubscription =
        _thermalPrinterManager.discovery(type: thermal.PrinterType.usb).listen(
      (device) {
        if (!mounted) return;
        final key = _usbDeviceKey(device);
        if (discoveredKeys.contains(key)) return;
        discoveredKeys.add(key);
        discoveredDevices.add(device);

        setState(() {
          _usbDevices = List<thermal.PrinterDevice>.from(discoveredDevices);
          _selectedUsbPrinter = _resolveUsbSelection(
            _selectedUsbPrinter,
            _usbDevices,
          );
        });
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _lastUsbDiscoveryError = _truncateDebugText(error.toString());
            _isUsbScanInProgress = false;
          });
        }
        debugPrint('USB discovery failed: $error');
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isUsbScanInProgress = false;
        });
      },
    );

    await Future<void>.delayed(const Duration(seconds: 6));
    await _stopUsbDiscovery();
    if (!mounted) return;

    if (showEmptyMessage && _usbDevices.isEmpty) {
      _showMessage('No USB printer found. Check OTG cable and printer power.');
    }
  }

  Future<void> _connectUsbPrinter({bool showMessage = true}) async {
    var selectedUsbPrinter = _selectedUsbPrinter;
    if (selectedUsbPrinter == null) {
      await _refreshUsbPrinters(showEmptyMessage: false);
      if (!mounted) return;

      if (_usbDevices.isNotEmpty) {
        setState(() {
          _selectedUsbPrinter = _usbDevices.first;
        });
        selectedUsbPrinter = _selectedUsbPrinter;
      }
    }

    if (selectedUsbPrinter == null) {
      if (showMessage) {
        _showMessage(
          'No USB printer detected yet. Reconnect cable, power on printer, then tap Scan USB.',
        );
      }
      return;
    }

    final vendorId = selectedUsbPrinter.vendorId;
    final productId = selectedUsbPrinter.productId;
    if (vendorId == null || productId == null) {
      if (showMessage) {
        _showMessage('Selected USB printer missing vendor/product ID.');
      }
      return;
    }

    try {
      await _thermalPrinterManager.connect(
        type: thermal.PrinterType.usb,
        model: thermal.UsbPrinterInput(
          name: selectedUsbPrinter.name,
          productId: productId,
          vendorId: vendorId,
        ),
      );

      if (!mounted) return;
      setState(() {
        _isUsbPrinterConnected = true;
        _usbNeedsRecoveryAfterResume = false;
        _lastUsbConnectAt = DateTime.now();
        _lastUsbConnectError = null;
      });
      if (showMessage) {
        _showMessage('USB printer connected: ${selectedUsbPrinter.name}');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isUsbPrinterConnected = false;
        _lastUsbConnectAt = DateTime.now();
        _lastUsbConnectError = _truncateDebugText(error.toString());
      });
      if (showMessage) {
        _showMessage('Failed to connect USB printer.');
      }
      debugPrint('USB connect failed: $error');
    }
  }

  Future<void> _disconnectUsbPrinter({bool showMessage = true}) async {
    try {
      await _thermalPrinterManager.disconnect(type: thermal.PrinterType.usb);
    } catch (error) {
      debugPrint('USB disconnect failed: $error');
    }

    if (!mounted) return;
    setState(() {
      _isUsbPrinterConnected = false;
    });
    if (showMessage) {
      _showMessage('USB printer disconnected.');
    }
  }

  Future<void> _loadCatalogProducts() async {
    var products = await _productStorage.loadProducts();
    var seededFromAsset = false;
    if (products.isEmpty) {
      final bundledProducts = await _loadBundledCatalogProducts();
      if (bundledProducts.isNotEmpty) {
        products = bundledProducts;
        seededFromAsset = true;
        await _productStorage.saveProducts(products);
      }
    }

    if (!mounted) return;

    setState(() {
      _catalogProducts = products;
      _selectedCatalogProduct =
          _catalogProducts.isEmpty ? null : _catalogProducts.first;
      if (_catalogProducts.isEmpty) {
        _promoFormProductId = null;
      } else if (_promoFormProductId == null ||
          !_catalogProducts
              .any((product) => product.id == _promoFormProductId)) {
        _promoFormProductId = _catalogProducts.first.id;
      }
      if (_selectedPromoConfigId != null &&
          !_promoConfigs.any((promo) => promo.id == _selectedPromoConfigId)) {
        _selectedPromoConfigId = null;
      }
    });

    if (seededFromAsset) {
      _showMessage('Default menu loaded from bundled catalog.');
    }
  }

  Future<List<Product>> _loadBundledCatalogProducts() async {
    try {
      final rawContent = await rootBundle.loadString(_defaultCatalogAssetPath);
      final lines = rawContent.split('\n');
      final products = <Product>[];
      var skippedRows = 0;

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        final parts = line.split(';').map((part) => part.trim()).toList();
        if (parts.length < 3) {
          skippedRows++;
          continue;
        }

        final name = parts[0].replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
        final price = int.tryParse(parts[1]);
        final category = _normalizeBundledCategory(parts[2]);

        if (name.isEmpty || price == null || price <= 0) {
          skippedRows++;
          continue;
        }

        products.add(
          Product(
            id: '${DateTime.now().microsecondsSinceEpoch}_${products.length}',
            name: name,
            price: price,
            category: category,
          ),
        );
      }

      if (skippedRows > 0) {
        debugPrint(
          'Bundled menu import skipped $skippedRows malformed row(s).',
        );
      }

      return products;
    } catch (error) {
      debugPrint('Failed loading bundled catalog asset: $error');
      return [];
    }
  }

  String _normalizeBundledCategory(String rawCategory) {
    final normalized = rawCategory.trim().toLowerCase();
    if (normalized == 'drink' || normalized == 'drinks') return 'Drinks';
    if (normalized == 'food') return 'Food';
    if (normalized == 'snack' || normalized == 'snacks') return 'Snacks';
    if (normalized == 'camilan') return 'Snacks';
    return 'Drinks';
  }

  Future<void> _resetCatalogToBundledMenu() async {
    if (!mounted) return;

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Catalog to Default Menu'),
        content: const Text(
          'This will replace your current catalog with the bundled default menu. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true) return;

    final bundledProducts = await _loadBundledCatalogProducts();
    if (bundledProducts.isEmpty) {
      _showMessage('Bundled menu is empty or invalid.');
      return;
    }

    setState(() {
      _catalogProducts = bundledProducts;
      _selectedCatalogProduct = bundledProducts.first;
      _promoFormProductId = bundledProducts.first.id;
      if (_selectedPromoConfigId != null &&
          !_promoConfigs.any((promo) => promo.id == _selectedPromoConfigId)) {
        _selectedPromoConfigId = null;
      }
      _catalogSearchController.clear();
      _catalogSearchQuery = '';
    });

    await _saveCatalogProducts();
    _showMessage(
        'Catalog reset to bundled menu (${bundledProducts.length} items).');
  }

  Future<void> _loadReceiptSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;

    _storeNameController.text =
        preferences.getString(_storeNameKey) ?? _storeNameController.text;
    _storeAddressController.text =
        preferences.getString(_storeAddressKey) ?? _storeAddressController.text;
    _bookingWhatsappController.text =
        preferences.getString(_bookingWhatsappKey) ?? '';
    _wifiNameController.text = preferences.getString(_wifiNameKey) ?? '';
    _wifiPasswordController.text =
        preferences.getString(_wifiPasswordKey) ?? '';
  }

  Future<void> _saveReceiptSettings() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storeNameKey, _storeNameController.text);
    await preferences.setString(
      _storeAddressKey,
      _storeAddressController.text,
    );
    await preferences.setString(
      _bookingWhatsappKey,
      _bookingWhatsappController.text,
    );
    await preferences.setString(_wifiNameKey, _wifiNameController.text);
    await preferences.setString(
      _wifiPasswordKey,
      _wifiPasswordController.text,
    );
  }

  Future<void> _saveCatalogProducts() async {
    await _productStorage.saveProducts(_catalogProducts);
  }

  Future<void> _loadTransactions() async {
    final transactions = await _transactionStorage.loadTransactions();
    if (!mounted) return;

    setState(() {
      _transactions = transactions;
    });
    await _removeSyncedOrdersFromBarIfNeeded();
  }

  Future<void> _saveTransactions() async {
    await _transactionStorage.saveTransactions(_transactions);
  }

  Future<void> _loadIncomingOrders() async {
    final orders = await _orderTicketStorage.loadOrderTickets();
    if (!mounted) return;

    setState(() {
      _incomingOrders = orders;
    });
    await _removeSyncedOrdersFromBarIfNeeded();
  }

  Future<void> _saveIncomingOrders() async {
    await _orderTicketStorage.saveOrderTickets(_incomingOrders);
  }

  Future<void> _removeIncomingOrdersByIds(Set<String> orderIds) async {
    if (orderIds.isEmpty) return;

    final filtered =
        _incomingOrders.where((order) => !orderIds.contains(order.id)).toList();
    final didChange = filtered.length != _incomingOrders.length;
    if (!didChange) return;

    if (!mounted) return;
    setState(() {
      _incomingOrders = filtered;
    });
    await _saveIncomingOrders();
  }

  Future<void> _removeSyncedOrdersFromBarIfNeeded() async {
    final syncedOrderIds = _transactions
        .where((transaction) => transaction.synced)
        .map((transaction) => transaction.id)
        .toSet();

    await _removeIncomingOrdersByIds(syncedOrderIds);
  }

  Future<void> _loadSyncCsvHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final savedPaths =
        preferences.getStringList(_syncCsvHistoryKey) ?? <String>[];

    final existingPaths = <String>[];
    for (final filePath in savedPaths) {
      if (await File(filePath).exists()) {
        existingPaths.add(filePath);
      }
    }

    if (savedPaths.length != existingPaths.length) {
      await preferences.setStringList(_syncCsvHistoryKey, existingPaths);
    }

    if (!mounted) return;
    setState(() {
      _syncCsvHistory = existingPaths;
    });
  }

  Future<void> _loadPromoConfigs() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_promoConfigsKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _promoConfigs = [];
        _selectedPromoConfigId = null;
      });
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        if (!mounted) return;
        setState(() {
          _promoConfigs = [];
          _selectedPromoConfigId = null;
        });
        return;
      }

      final loadedPromos = <_PromoConfig>[];
      for (final rawPromo in decoded) {
        if (rawPromo is Map<String, dynamic>) {
          loadedPromos.add(_PromoConfig.fromJson(rawPromo));
          continue;
        }
        if (rawPromo is Map) {
          loadedPromos
              .add(_PromoConfig.fromJson(rawPromo.cast<String, dynamic>()));
        }
      }

      if (!mounted) return;
      setState(() {
        _promoConfigs = loadedPromos;
        if (_selectedPromoConfigId != null &&
            !_promoConfigs.any((promo) => promo.id == _selectedPromoConfigId)) {
          _selectedPromoConfigId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _promoConfigs = [];
        _selectedPromoConfigId = null;
      });
    }
  }

  Future<void> _savePromoConfigs() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(_promoConfigs.map((promo) => promo.toJson()).toList());
    await preferences.setString(_promoConfigsKey, encoded);
  }

  String _productNameById(String productId) {
    for (final product in _catalogProducts) {
      if (product.id == productId) return product.name;
    }
    return 'Unknown product';
  }

  String _productCategoryById(String productId) {
    for (final product in _catalogProducts) {
      if (product.id == productId) return product.category;
    }
    return '';
  }

  String _promoDisplayLabel(_PromoConfig promo) {
    final productName = _productNameById(promo.productId);
    if (promo.type == _PromoType.percentageProduct) {
      return '${promo.discountPercent}% off - $productName';
    }
    if (promo.type == _PromoType.percentageCategory) {
      final scope =
          promo.categoryScope.isEmpty ? 'All categories' : promo.categoryScope;
      return '${promo.discountPercent}% off - Category $scope';
    }
    if (promo.type == _PromoType.buy1Get1CrossProduct) {
      if (promo.categoryScope.isNotEmpty) {
        return 'Buy 1 Get 1 Cross Product (${promo.categoryScope})';
      }
      return 'Buy 1 Get 1 Cross Product';
    }
    return 'Buy 1 Get 1 - $productName';
  }

  String _promoSalesDropdownLabel(_PromoConfig promo) {
    switch (promo.type) {
      case _PromoType.percentageProduct:
        return '[Product] ${_promoDisplayLabel(promo)}';
      case _PromoType.percentageCategory:
        return '[Category] ${_promoDisplayLabel(promo)}';
      case _PromoType.buy1Get1:
        return '[Product] ${_promoDisplayLabel(promo)}';
      case _PromoType.buy1Get1CrossProduct:
        return '[Cross Category] ${_promoDisplayLabel(promo)}';
    }
  }

  String _formatIdr(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final positionFromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp$buffer';
  }

  List<String> _buildPromoFreeItemNotes(
    List<ReceiptItem> items,
    _PromoConfig? promo,
  ) {
    if (promo == null || items.isEmpty) return const [];

    if (promo.type == _PromoType.buy1Get1CrossProduct) {
      final eligibleUnits = <_PromoUnit>[];
      for (final item in items) {
        if (promo.categoryScope.isNotEmpty) {
          final itemCategory = _productCategoryById(item.productId);
          if (itemCategory != promo.categoryScope) continue;
        }
        for (var i = 0; i < item.quantity; i++) {
          eligibleUnits.add(_PromoUnit(name: item.name, price: item.unitPrice));
        }
      }

      if (eligibleUnits.isEmpty) {
        return const ['Eligible items: 0'];
      }

      eligibleUnits.sort((a, b) {
        final priceCompare = a.price.compareTo(b.price);
        if (priceCompare != 0) return priceCompare;
        return a.name.compareTo(b.name);
      });

      if (eligibleUnits.length < 2) {
        return [
          'Eligible items: ${eligibleUnits.length}. Need at least 2 eligible items.',
        ];
      }

      final freeUnit = eligibleUnits.first;
      final scope =
          promo.categoryScope.isEmpty ? 'All categories' : promo.categoryScope;

      return [
        'Eligible ($scope): ${eligibleUnits.length} item(s)',
        'Free item: ${freeUnit.name} (${_formatIdr(freeUnit.price)})',
        'Free total: ${_formatIdr(freeUnit.price)}',
      ];
    }

    if (promo.type == _PromoType.buy1Get1) {
      var eligibleQty = 0;
      var unitPrice = 0;
      var productName = _productNameById(promo.productId);

      for (final item in items) {
        if (item.productId != promo.productId) continue;
        eligibleQty += item.quantity;
        unitPrice = item.unitPrice;
        if (productName == 'Unknown product') {
          productName = item.name;
        }
      }

      final freeQty = eligibleQty ~/ 2;
      if (freeQty == 0) {
        return [
          'Eligible $productName: $eligibleQty item(s). Need at least 2.',
        ];
      }

      final freeTotal = freeQty * unitPrice;
      return [
        'Eligible $productName: $eligibleQty item(s)',
        'Free items: $productName x$freeQty (${_formatIdr(unitPrice)} each)',
        'Free total: ${_formatIdr(freeTotal)}',
      ];
    }

    return const [];
  }

  int _calculatePromoDiscount(
    List<ReceiptItem> items,
    _PromoConfig promo,
  ) {
    if (items.isEmpty) return 0;

    if (promo.type == _PromoType.percentageProduct) {
      var matchedSubtotal = 0;
      for (final item in items) {
        if (item.productId == promo.productId) {
          matchedSubtotal += item.total;
        }
      }
      return ((matchedSubtotal * promo.discountPercent) / 100).round();
    }

    if (promo.type == _PromoType.percentageCategory) {
      var matchedSubtotal = 0;
      for (final item in items) {
        final itemCategory = _productCategoryById(item.productId);
        if (promo.categoryScope.isEmpty ||
            itemCategory == promo.categoryScope) {
          matchedSubtotal += item.total;
        }
      }
      return ((matchedSubtotal * promo.discountPercent) / 100).round();
    }

    if (promo.type == _PromoType.buy1Get1CrossProduct) {
      final prices = <int>[];
      for (final item in items) {
        if (promo.categoryScope.isNotEmpty) {
          final itemCategory = _productCategoryById(item.productId);
          if (itemCategory != promo.categoryScope) {
            continue;
          }
        }
        for (var i = 0; i < item.quantity; i++) {
          prices.add(item.unitPrice);
        }
      }

      if (prices.isEmpty) return 0;
      if (prices.length < 2) return 0;

      prices.sort();
      return prices.first;
    }

    var totalQty = 0;
    var unitPrice = 0;
    for (final item in items) {
      if (item.productId == promo.productId) {
        totalQty += item.quantity;
        unitPrice = item.unitPrice;
      }
    }
    final freeQty = totalQty ~/ 2;
    return freeQty * unitPrice;
  }

  String _buildReceiptPromoLabel(
    List<ReceiptItem> items,
    _PromoConfig? promo,
  ) {
    if (promo == null) return '';

    final baseLabel = _promoDisplayLabel(promo);
    final promoNotes = _buildPromoFreeItemNotes(items, promo);
    for (final note in promoNotes) {
      if (note.startsWith('Free item:') || note.startsWith('Free items:')) {
        return '$baseLabel | $note';
      }
    }

    return baseLabel;
  }

  _PricingSummary _calculatePricingSummary(
    List<ReceiptItem> items, {
    _PromoConfig? promo,
  }) {
    final grossSubtotal = items.fold(0, (sum, item) => sum + item.total);

    if (promo == null) {
      return _PricingSummary(
        grossSubtotal: grossSubtotal,
        discountAmount: 0,
        netSubtotal: grossSubtotal,
        promoType: 'none',
        promoLabel: '',
      );
    }

    final rawDiscount = _calculatePromoDiscount(items, promo);
    final discountAmount = rawDiscount < 0
        ? 0
        : (rawDiscount > grossSubtotal ? grossSubtotal : rawDiscount);
    final netSubtotal = grossSubtotal - discountAmount;

    return _PricingSummary(
      grossSubtotal: grossSubtotal,
      discountAmount: discountAmount,
      netSubtotal: netSubtotal,
      promoType: promo.type.code,
      promoLabel: _promoDisplayLabel(promo),
    );
  }

  Future<void> _addProductToCatalog() async {
    final name = _productNameController.text.trim();
    final price = int.tryParse(_productPriceController.text.trim());

    if (name.isEmpty || price == null || price <= 0) {
      _showMessage('Enter a valid product name and price.');
      return;
    }

    final product = Product(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      price: price,
      category: _selectedProductCategory,
    );

    setState(() {
      _catalogProducts.add(product);
      _selectedCatalogProduct = product;
      _productNameController.clear();
      _productPriceController.clear();
      _selectedProductCategory = _productCategories.first;
    });

    await _saveCatalogProducts();
    _showMessage('Product saved locally.');
  }

  Future<void> _removeProductFromCatalog(String productId) async {
    final product = _catalogProducts
        .cast<Product?>()
        .firstWhere((p) => p?.id == productId, orElse: () => null);
    final productName = product?.name ?? 'this product';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'Warning: "$productName" will be permanently deleted from your catalog.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      _catalogProducts.removeWhere((p) => p.id == productId);
      if (_catalogProducts.isEmpty) {
        _selectedCatalogProduct = null;
      } else if (_selectedCatalogProduct?.id == productId) {
        _selectedCatalogProduct = _catalogProducts.first;
      }
    });

    await _saveCatalogProducts();
    _showMessage('Product deleted.');
  }

  Future<void> _editProductInCatalog(Product product) async {
    final nameController = TextEditingController(text: product.name);
    final priceController =
        TextEditingController(text: product.price.toString());
    var selectedCategory = _productCategories.contains(product.category)
        ? product.category
        : _productCategories.first;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Product name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Price',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: _productCategories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedCategory = value;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Category',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (didSave != true) {
      nameController.dispose();
      priceController.dispose();
      return;
    }

    final updatedName = nameController.text.trim();
    final updatedPrice = int.tryParse(priceController.text.trim());

    nameController.dispose();
    priceController.dispose();

    if (updatedName.isEmpty || updatedPrice == null || updatedPrice <= 0) {
      _showMessage('Enter a valid product name and price.');
      return;
    }

    final updatedProduct = Product(
      id: product.id,
      name: updatedName,
      price: updatedPrice,
      category: selectedCategory,
    );

    setState(() {
      _catalogProducts = _catalogProducts
          .map((p) => p.id == product.id ? updatedProduct : p)
          .toList();
      if (_selectedCatalogProduct?.id == product.id) {
        _selectedCatalogProduct = updatedProduct;
      }
    });

    await _saveCatalogProducts();
    _showMessage('Product updated.');
  }

  void _addSelectedProductToCart() {
    final product = _selectedCatalogProduct;
    final qty = int.tryParse(_saleQtyController.text.trim());
    final note = _saleItemNoteController.text.trim();

    if (product == null) {
      _showMessage('Please add and select a product first.');
      return;
    }

    if (qty == null || qty <= 0) {
      _showMessage('Enter a valid quantity.');
      return;
    }

    setState(() {
      _items.add(
        ReceiptItem(
          productId: product.id,
          name: product.name,
          quantity: qty,
          unitPrice: product.price,
          note: note,
        ),
      );
      _saleQtyController.text = '1';
      _saleItemNoteController.clear();
    });
  }

  void _removeCartItem(int index) {
    final removedItem = _items[index];

    setState(() {
      _items.removeAt(index);
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${removedItem.name} from cart.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted) return;
              setState(() {
                final safeIndex = index.clamp(0, _items.length);
                _items.insert(safeIndex, removedItem);
              });
            },
          ),
        ),
      );
  }

  Future<void> _showReceiptPreview() async {
    if (_items.isEmpty) {
      _showMessage('Add at least one item first.');
      return;
    }

    final customerName = _customerNameController.text.trim();
    final orderNumber = _orderNumberController.text.trim();
    if (customerName.isEmpty || orderNumber.isEmpty) {
      _showMessage('Enter customer name and order number first.');
      return;
    }

    if (!mounted) return;

    final transactionDateTime = DateTime.now();
    final lines = _buildReceiptLines(transactionDateTime: transactionDateTime);
    final previewBodyText = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Receipt Preview'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogoPreviewWidget(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _resolvedStoreName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (previewBodyText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SelectableText(
                              previewBodyText,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.print),
              label: const Text('Print Now'),
            ),
          ],
        );
      },
    );

    if (shouldPrint != true) return;

    _showMessage('Starting print...');
    try {
      await _printReceipt(lines, transactionDateTime);
    } catch (error, stackTrace) {
      debugPrint('Receipt print pipeline crashed: $error');
      debugPrint('Receipt print pipeline stack: $stackTrace');
      final reason = _truncateDebugText(error.toString(), maxLength: 120);
      _showMessage(
        'Print pipeline failed early: $reason',
      );
    }
  }

  Widget _buildLogoPreviewWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Image.asset(
          _logoAssetPath,
          height: _logoPreviewHeight,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              height: _logoPreviewHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined, size: 22),
                  SizedBox(height: 4),
                  Text('Logo failed to load'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<bool> _ensurePrinterReadyForPrint() async {
    if (_printerConnectionMode == _PrinterConnectionMode.usb) {
      return _ensureUsbPrinterReadyForPrint();
    }

    return _ensureBluetoothPrinterReadyForPrint();
  }

  Future<bool> _ensureBluetoothPrinterReadyForPrint() async {
    if (_isUsbScanInProgress) {
      await _stopUsbDiscovery();
    }

    final granted = await _ensureBluetoothPermission();
    if (!granted) {
      _showMessage('Grant Nearby devices permission first.');
      return false;
    }

    if (_selectedPrinter == null) {
      await _loadPairedPrinters(showMessage: false);
    }

    if (_selectedPrinter == null) {
      _showMessage('Select a paired Bluetooth printer in Settings first.');
      return false;
    }

    // Connect here so any failure is surfaced with a clear message before
    // bytes are built or the write path is entered.
    final didConnect = await _tryConnectBluetoothWithRetries();
    if (!didConnect) {
      _showMessage(
        'Could not connect to printer. Make sure it is on and in range.',
      );
    }
    return didConnect;
  }

  Future<bool> _ensureUsbPrinterReadyForPrint() async {
    var selectedUsbPrinter = _selectedUsbPrinter;

    if (_isUsbScanInProgress) {
      await _stopUsbDiscovery();
    }

    Future<void> refreshAndRebindSelection() async {
      final previousKey = selectedUsbPrinter == null
          ? null
          : _usbDeviceKey(selectedUsbPrinter!);

      await _refreshUsbPrinters(showEmptyMessage: false);
      if (!mounted) return;
      if (_usbDevices.isEmpty) return;

      thermal.PrinterDevice resolved = _usbDevices.first;
      if (previousKey != null) {
        for (final device in _usbDevices) {
          if (_usbDeviceKey(device) == previousKey) {
            resolved = device;
            break;
          }
        }
      }

      setState(() {
        _selectedUsbPrinter = resolved;
      });
      selectedUsbPrinter = resolved;
    }

    if (selectedUsbPrinter == null) {
      await refreshAndRebindSelection();
      selectedUsbPrinter = _selectedUsbPrinter;
    }

    if (selectedUsbPrinter == null) {
      _showMessage('No USB printer selected. Tap Scan USB and choose printer.');
      return false;
    }

    if (_usbNeedsRecoveryAfterResume) {
      await _disconnectUsbPrinter(showMessage: false);
      await _connectUsbPrinter(showMessage: false);
      if (_isUsbPrinterConnected) {
        if (mounted) {
          setState(() {
            _usbNeedsRecoveryAfterResume = false;
          });
        }
        return true;
      }
    }

    await _disconnectUsbPrinter(showMessage: false);
    await _connectUsbPrinter(showMessage: false);
    if (_isUsbPrinterConnected) {
      return true;
    }

    await refreshAndRebindSelection();
    await _disconnectUsbPrinter(showMessage: false);
    await _connectUsbPrinter(showMessage: false);
    if (_isUsbPrinterConnected) {
      return true;
    }

    _showMessage(
      'USB printer not ready after wake. Tap Scan USB, then reconnect cable if needed.',
    );
    return false;
  }

  List<String> _buildReceiptLines({required DateTime transactionDateTime}) {
    final pricingSummary = _currentPricingSummary;
    return ReceiptBuilder.buildReceiptLines(
      storeName: _resolvedStoreName,
      storeAddress: _storeAddressController.text.trim(),
      transactionDateTime: transactionDateTime,
      items: _items,
      customerName: _customerNameController.text.trim(),
      orderNumber: _orderNumberController.text.trim(),
      paymentMethod: _selectedPaymentMethod,
      bookingWhatsappNumber: _bookingWhatsappController.text.trim(),
      wifiName: _wifiNameController.text.trim(),
      wifiPassword: _wifiPasswordController.text.trim(),
      discountAmount: pricingSummary.discountAmount,
      promoLabel: _buildReceiptPromoLabel(_items, _selectedPromoConfig),
      paidAmount: pricingSummary.netSubtotal,
      lineWidth: _lineWidth,
    );
  }

  Future<void> _printReceipt(
    List<String> lines,
    DateTime transactionDateTime,
  ) async {
    var step = 'start';
    try {
      step = 'ensure printer ready';
      final printerReady = await _ensurePrinterReadyForPrint();
      if (!printerReady) {
        _showMessage('Printer is not ready. Please reconnect and try again.');
        return;
      }

      step = 'build transaction snapshot';
      final printedItems = List<ReceiptItem>.from(_items);
      final pricingSummary = _currentPricingSummary;
      final printedTotal = pricingSummary.netSubtotal;

      step = 'load capability profile';
      final profile = await CapabilityProfile.load();
      step = 'build esc/pos generator';
      final generator = Generator(_selectedPaperSize, profile);
      final bytes = <int>[];

      step = 'append logo bytes';
      await _appendLogoToReceiptBytes(bytes, generator);

      step = 'append receipt text bytes';
      for (var i = 0; i < lines.length; i++) {
        final line = _sanitizePrinterText(lines[i]);
        bytes.addAll(
          generator.text(
            line,
            styles: const PosStyles(
              align: PosAlign.left,
              width: PosTextSize.size1,
              height: PosTextSize.size1,
            ),
          ),
        );
      }
      bytes.addAll(generator.cut());

      step = 'write bytes to printer';
      final result = await _writeBytesWithRecovery(bytes,
          printerType: _PrinterType.invoice);
      if (!result) {
        _showMessage('Print failed. Please retry.');
        return;
      }

      step = 'build transaction models';
      final transaction = PosTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAtIso: transactionDateTime.toIso8601String(),
        storeName: _resolvedStoreName,
        paymentMethod: _selectedPaymentMethod,
        lines: printedItems
            .map(
              (item) => TransactionLine(
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                note: item.note,
              ),
            )
            .toList(),
        total: printedTotal,
        promoType: pricingSummary.promoType,
        promoLabel: pricingSummary.promoLabel,
        grossSubtotal: pricingSummary.grossSubtotal,
        discountAmount: pricingSummary.discountAmount,
        synced: false,
      );

      final incomingOrder = OrderTicket(
        id: transaction.id,
        orderNumber: _orderNumberController.text.trim(),
        customerName: _customerNameController.text.trim(),
        createdAtIso: transactionDateTime.toIso8601String(),
        total: printedTotal,
        itemCount: printedItems.length,
        items: printedItems
            .map(
              (item) => OrderTicketItem(
                name: item.name,
                quantity: item.quantity,
                note: item.note,
              ),
            )
            .toList(),
        status: OrderTicketStatus.incoming,
      );

      step = 'persist transaction data';
      setState(() {
        _transactions = [transaction, ..._transactions];
        _incomingOrders = [incomingOrder, ..._incomingOrders];
        _items.clear();
        _customerNameController.clear();
      });
      await _saveTransactions();
      await _saveIncomingOrders();
      await _generateNextOrderNumber();

      step = 'finish';
      _showMessage('Receipt sent to printer.');
    } catch (error, stackTrace) {
      debugPrint('Unexpected error while printing receipt: $error');
      debugPrint('Unexpected receipt stack at step "$step": $stackTrace');
      final reason = _truncateDebugText(error.toString(), maxLength: 120);
      _showMessage(
        'Unexpected print error at "$step": $reason',
      );
    }
  }

  Future<void> _advanceBarOrderStatus(OrderTicket order) async {
    if (order.isFinished) {
      _showMessage('Order ${order.orderNumber} is already finished.');
      return;
    }

    if (order.isOnProgress) {
      setState(() {
        _incomingOrders = _incomingOrders
            .map(
              (o) => o.id == order.id
                  ? o.copyWith(status: OrderTicketStatus.finished)
                  : o,
            )
            .toList();
      });
      await _saveIncomingOrders();
      _showMessage('Order ${order.orderNumber} marked as Finished.');
      return;
    }

    final printerReady = await _ensurePrinterReadyForPrint();
    if (!printerReady) {
      _showMessage('Printer is not ready. Please reconnect and try again.');
      return;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(_selectedPaperSize, profile);
    final bytes = <int>[];

    void appendProductLabel({
      required String productName,
      required String itemNote,
      required int copyIndex,
      required int totalCopies,
    }) {
      bytes.addAll(
        generator.text(
          'ORDER READY',
          styles: const PosStyles(
            align: PosAlign.center,
            width: PosTextSize.size1,
            height: PosTextSize.size1,
            bold: true,
          ),
        ),
      );
      bytes.addAll(
        generator.text(
          'Order #${order.orderNumber}',
          styles: const PosStyles(
            align: PosAlign.center,
            width: PosTextSize.size1,
            height: PosTextSize.size1,
            bold: true,
          ),
        ),
      );
      bytes.addAll(
        generator.text(
          _sanitizePrinterText(order.customerName),
          styles: const PosStyles(
            align: PosAlign.center,
            width: PosTextSize.size1,
            height: PosTextSize.size1,
            bold: true,
          ),
        ),
      );
      bytes.addAll(
        generator.text(
          _sanitizePrinterText(productName),
          styles: const PosStyles(
            align: PosAlign.center,
            width: PosTextSize.size1,
            height: PosTextSize.size1,
            bold: true,
          ),
        ),
      );
      final normalizedNote = itemNote.trim();
      if (normalizedNote.isNotEmpty) {
        bytes.addAll(
          generator.text(
            _sanitizePrinterText('Note: $normalizedNote'),
            styles: const PosStyles(
              align: PosAlign.center,
              width: PosTextSize.size1,
              height: PosTextSize.size1,
            ),
          ),
        );
      }
      if (totalCopies > 1) {
        bytes.addAll(
          generator.text(
            'Cup ${copyIndex + 1}/$totalCopies',
            styles: const PosStyles(align: PosAlign.center),
          ),
        );
      }
      bytes.addAll(generator.emptyLines(1));
      bytes.addAll(generator.cut());
    }

    if (order.items.isEmpty) {
      appendProductLabel(
        productName: 'Items: ${order.itemCount} | Total: Rp${order.total}',
        itemNote: '',
        copyIndex: 0,
        totalCopies: 1,
      );
    } else {
      for (final item in order.items) {
        final totalCopies = item.quantity <= 0 ? 1 : item.quantity;
        for (var copyIndex = 0; copyIndex < totalCopies; copyIndex++) {
          appendProductLabel(
            productName: item.name,
            itemNote: item.note,
            copyIndex: copyIndex,
            totalCopies: totalCopies,
          );
        }
      }
    }

    final result =
        await _writeBytesWithRecovery(bytes, printerType: _PrinterType.label);
    if (!result) {
      _showMessage('Failed to print bartender label.');
      return;
    }

    setState(() {
      _incomingOrders = _incomingOrders
          .map(
            (o) => o.id == order.id
                ? o.copyWith(status: OrderTicketStatus.onProgress)
                : o,
          )
          .toList();
    });
    await _saveIncomingOrders();
    _showMessage(
        'Order ${order.orderNumber} is On-Progress and label printed.');
  }

  Future<bool> _writeBytesWithRecovery(
    List<int> bytes, {
    _PrinterType printerType = _PrinterType.invoice,
  }) async {
    if (bytes.isEmpty) return false;

    final printerMode = _printerModeForType(printerType);
    final selectedUsbPrinter = _selectedUsbPrinterForType(printerType);

    if (printerMode == _PrinterConnectionMode.usb) {
      if (selectedUsbPrinter == null) return false;

      var didSend = false;

      try {
        await _thermalPrinterManager.send(
          type: thermal.PrinterType.usb,
          bytes: bytes,
        );
        if (mounted) {
          setState(() {
            _lastUsbPrintAt = DateTime.now();
            _lastUsbPrintSuccess = true;
            _lastUsbPrintError = null;
          });
        }
        didSend = true;
        return true;
      } catch (error) {
        if (mounted) {
          setState(() {
            _setUsbConnected(printerType, false);
            _lastUsbPrintAt = DateTime.now();
            _lastUsbPrintSuccess = false;
            _lastUsbPrintError = _truncateDebugText(error.toString());
          });
        }
        debugPrint('USB print first attempt failed: $error');
      }

      try {
        // Note: For dual printer support, you would need to add type-specific
        // disconnect/connect methods. For now using legacy methods.
        await _disconnectUsbPrinter(showMessage: false);
        await _connectUsbPrinter(showMessage: false);
        if (!_isUsbPrinterConnected) return false;

        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _thermalPrinterManager.send(
          type: thermal.PrinterType.usb,
          bytes: bytes,
        );
        if (mounted) {
          setState(() {
            _lastUsbPrintAt = DateTime.now();
            _lastUsbPrintSuccess = true;
            _lastUsbPrintError = null;
          });
        }
        didSend = true;
        return true;
      } catch (error) {
        if (mounted) {
          setState(() {
            _setUsbConnected(printerType, false);
            _lastUsbPrintAt = DateTime.now();
            _lastUsbPrintSuccess = false;
            _lastUsbPrintError = _truncateDebugText(error.toString());
          });
        }
        debugPrint('USB print retry failed: $error');
        return false;
      } finally {
        if (didSend) {
          await _disconnectUsbPrinter(showMessage: false);
        }
      }
    }

    // Bluetooth path — connection was established by _ensurePrinterReadyForPrint.
    // Write attempt 0: socket is already connected.
    // Write attempt 1: reconnect first (socket may have gone stale).
    // Note: Bluetooth write uses legacy PrintBluetoothThermal library which
    // manages a single connection. For true dual-printer support with Bluetooth,
    // additional libraries or native platform code would be needed.
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt == 1) {
        // Stale socket — disconnect cleanly and reconnect once before retrying.
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final didReconnect = await _tryConnectBluetoothWithRetries();
        if (!didReconnect) break;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      try {
        final didWrite = await PrintBluetoothThermal.writeBytes(bytes);
        if (didWrite) {
          if (mounted) {
            setState(() => _setBtConnected(printerType, true));
          }
          return true;
        }
        debugPrint('BT writeBytes returned false on attempt #${attempt + 1}');
      } catch (error) {
        debugPrint('BT write attempt #${attempt + 1} threw: $error');
      }
    }

    if (mounted) {
      setState(() {
        _setBtConnected(printerType, false);
      });
    }
    return false;
  }

  Future<void> _appendLogoToReceiptBytes(
    List<int> bytes,
    Generator generator,
  ) async {
    try {
      const escAlignCenter = [0x1B, 0x61, 0x01];
      const escAlignLeft = [0x1B, 0x61, 0x00];

      final rawLogoBytes = await rootBundle.load(_logoAssetPath);
      final decoded = img.decodeImage(rawLogoBytes.buffer.asUint8List());
      if (decoded == null) {
        debugPrint('Logo decode failed: $_logoAssetPath');
        return;
      }

      final thermalReadyLogo = _prepareLogoForThermalPrint(decoded);

      var logoPrinted = false;

      try {
        bytes.addAll(escAlignCenter);
        bytes.addAll(
          generator.imageRaster(
            thermalReadyLogo,
            align: PosAlign.center,
            imageFn: PosImageFn.bitImageRaster,
          ),
        );
        logoPrinted = true;
      } catch (e) {
        debugPrint('Logo print fallback (bitImageRaster) failed: $e');
      }

      if (!logoPrinted) {
        try {
          bytes.addAll(escAlignCenter);
          bytes.addAll(
            generator.imageRaster(
              thermalReadyLogo,
              align: PosAlign.center,
              imageFn: PosImageFn.graphics,
            ),
          );
          logoPrinted = true;
        } catch (e) {
          debugPrint('Logo print fallback (graphics) failed: $e');
        }
      }

      if (!logoPrinted) {
        try {
          bytes.addAll(escAlignCenter);
          bytes.addAll(
              generator.image(thermalReadyLogo, align: PosAlign.center));
          logoPrinted = true;
        } catch (e) {
          debugPrint('Logo print fallback (legacy image) failed: $e');
        }
      }

      if (logoPrinted) {
        bytes.addAll(generator.emptyLines(1));
      }

      bytes.addAll(escAlignLeft);
    } catch (e) {
      debugPrint('Logo append error: $e');
      // Keep receipt printing resilient even if logo asset fails to load.
    }
  }

  img.Image _prepareLogoForThermalPrint(img.Image source) {
    final grayscale = img.grayscale(source);
    final highContrast = img.contrast(grayscale, contrast: 90);

    final paperWidthDots = _selectedPaperSize == PaperSize.mm80 ? 576 : 384;
    final scaledWidth = (highContrast.width * _thermalLogoScaleFactor).round();
    final scaledLogo = img.copyResize(
      highContrast,
      width: scaledWidth < 1 ? 1 : scaledWidth,
      interpolation: img.Interpolation.linear,
    );

    final resized = scaledLogo.width > paperWidthDots
        ? img.copyResize(
            scaledLogo,
            width: paperWidthDots,
            interpolation: img.Interpolation.linear,
          )
        : scaledLogo;

    final monochrome = _toHighContrastMonochrome(resized, threshold: 165);
    return _centerLogoOnCanvas(monochrome, canvasWidth: paperWidthDots);
  }

  img.Image _centerLogoOnCanvas(
    img.Image logo, {
    required int canvasWidth,
  }) {
    final safeCanvasWidth = canvasWidth < logo.width ? logo.width : canvasWidth;
    final centeredCanvas = img.Image(
      width: safeCanvasWidth,
      height: logo.height,
      numChannels: 4,
    );

    img.fill(centeredCanvas, color: img.ColorRgba8(255, 255, 255, 255));

    final offsetX = ((safeCanvasWidth - logo.width) / 2).round();
    img.compositeImage(centeredCanvas, logo, dstX: offsetX, dstY: 0);
    return centeredCanvas;
  }

  img.Image _toHighContrastMonochrome(
    img.Image source, {
    required int threshold,
  }) {
    final output = img.Image.from(source);
    for (var y = 0; y < output.height; y++) {
      for (var x = 0; x < output.width; x++) {
        final pixel = output.getPixel(x, y);
        final luminance = ((pixel.r + pixel.g + pixel.b) / 3).round();
        final value = luminance >= threshold ? 255 : 0;
        output.setPixelRgba(x, y, value, value, value, 255);
      }
    }
    return output;
  }

  Future<void> _syncTransactionsByEmail() async {
    final pending = _transactions.where((t) => !t.synced).toList();
    if (pending.isEmpty) {
      _showMessage('No pending transactions to sync.');
      return;
    }

    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync to Email'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Destination email',
            hintText: 'you@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailController.text),
            child: const Text('Create Email'),
          ),
        ],
      ),
    );

    final targetEmail = email?.trim() ?? '';
    if (targetEmail.isEmpty) return;

    final csvFile = await _exportPendingTransactionsCsv(pending);
    if (csvFile == null) {
      _showMessage('Failed to generate CSV export file.');
      return;
    }

    final subject = 'POS Sync - ${DateTime.now().toIso8601String()}';
    final body = _buildSyncEmailBody(pending);

    await Share.shareXFiles(
      [XFile(csvFile.path, mimeType: 'text/csv')],
      subject: subject,
      text: 'Please email this CSV attachment to: $targetEmail\n\n$body',
    );

    if (!mounted) return;

    final didSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sync Status'),
        content: const Text(
          'Did you send the email with the attached CSV file?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, sent'),
          ),
        ],
      ),
    );

    if (didSend != true) {
      _showMessage(
        'CSV saved locally as ${csvFile.uri.pathSegments.last}. Transactions remain pending.',
      );
      return;
    }

    final pendingIds = pending.map((t) => t.id).toSet();
    setState(() {
      _transactions = _transactions
          .map((t) => pendingIds.contains(t.id) ? t.copyWith(synced: true) : t)
          .toList();
    });
    await _saveTransactions();
    await _removeIncomingOrdersByIds(pendingIds);

    _showMessage(
      'CSV synced for ${pending.length} transactions: ${csvFile.uri.pathSegments.last}',
    );
  }

  Future<File?> _exportPendingTransactionsCsv(
    List<PosTransaction> transactions,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportsDirectory = Directory('${directory.path}/sync_exports');
      if (!await exportsDirectory.exists()) {
        await exportsDirectory.create(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File('${exportsDirectory.path}/transactions_$timestamp.csv');

      final csvContent = _buildSyncCsv(transactions);
      await file.writeAsString(csvContent);
      await _recordCsvHistory(file.path);

      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordCsvHistory(String filePath) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getStringList(_syncCsvHistoryKey) ?? <String>[];
    final updated = [filePath, ...current.where((path) => path != filePath)];
    final capped = updated.take(30).toList();
    await preferences.setStringList(_syncCsvHistoryKey, capped);
    if (!mounted) return;
    setState(() {
      _syncCsvHistory = capped;
    });
  }

  Future<void> _shareSavedCsvExport(String filePath) async {
    final file = File(filePath);
    final exists = await file.exists();
    if (!exists) {
      _showMessage('CSV file no longer exists. Refreshing history.');
      await _loadSyncCsvHistory();
      return;
    }

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'POS Sync CSV Export',
      text: 'Re-share CSV export for reconciliation.',
    );
  }

  Future<void> _deleteSavedCsvExport(String filePath) async {
    if (!mounted) return;

    final fileName = File(filePath).uri.pathSegments.last;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete CSV Export'),
        content: Text('Delete "$fileName" from local storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getStringList(_syncCsvHistoryKey) ?? <String>[];
    final updated = current.where((path) => path != filePath).toList();
    await preferences.setStringList(_syncCsvHistoryKey, updated);

    if (!mounted) return;
    setState(() {
      _syncCsvHistory = updated;
    });

    _showMessage('Deleted CSV export: $fileName');
  }

  String _buildSyncCsv(List<PosTransaction> transactions) {
    final rows = <String>[
      'TransactionID,Timestamp,Store,PaymentMethod,PromoType,PromoLabel,GrossSubtotal,DiscountAmount,ItemName,Quantity,UnitPrice,LineTotal,Note,TransactionTotal',
    ];

    for (final transaction in transactions) {
      for (final line in transaction.lines) {
        rows.add(
          [
            transaction.id,
            transaction.createdAtIso,
            transaction.storeName,
            transaction.paymentMethod,
            transaction.promoType,
            transaction.promoLabel,
            transaction.grossSubtotal.toString(),
            transaction.discountAmount.toString(),
            line.name,
            line.quantity.toString(),
            line.unitPrice.toString(),
            line.total.toString(),
            line.note,
            transaction.total.toString(),
          ].map(_escapeCsvValue).join(','),
        );
      }
    }

    return '${rows.join('\n')}\n';
  }

  String _escapeCsvValue(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildSyncEmailBody(List<PosTransaction> transactions) {
    final lines = <String>[
      'POS Transactions Sync',
      'Generated: ${DateTime.now().toIso8601String()}',
      '',
      'ID,Timestamp,Store,PaymentMethod,PromoType,PromoLabel,GrossSubtotal,Discount,ItemCount,Total',
      ...transactions.map(
        (t) =>
            '${t.id},${t.createdAtIso},${t.storeName},${t.paymentMethod},${t.promoType},${t.promoLabel},${t.grossSubtotal},${t.discountAmount},${t.lines.length},${t.total}',
      ),
      '',
      'Detail Lines:',
    ];

    for (final transaction in transactions) {
      lines.add(
        'Transaction ${transaction.id} | payment=${transaction.paymentMethod} | promo=${transaction.promoLabel.isEmpty ? 'none' : transaction.promoLabel} | gross=${transaction.grossSubtotal} | discount=${transaction.discountAmount} | total=${transaction.total}',
      );
      for (final line in transaction.lines) {
        final noteText = line.note.trim().isEmpty ? '-' : line.note.trim();
        lines.add(
          '- ${line.name} | qty=${line.quantity} | price=${line.unitPrice} | total=${line.total} | note=$noteText',
        );
      }
      lines.add('---');
    }

    return lines.join('\n');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Choose printer and connect'),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Connection Mode:'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_PrinterConnectionMode>(
                segments: const [
                  ButtonSegment<_PrinterConnectionMode>(
                    value: _PrinterConnectionMode.bluetooth,
                    label: Text('Bluetooth'),
                  ),
                  ButtonSegment<_PrinterConnectionMode>(
                    value: _PrinterConnectionMode.usb,
                    label: Text('USB OTG'),
                  ),
                ],
                selected: {_printerConnectionMode},
                onSelectionChanged: (selection) {
                  _setPrinterConnectionMode(selection.first);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_printerConnectionMode == _PrinterConnectionMode.bluetooth) ...[
          if (!_isBluetoothPermissionGranted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bluetooth permission is required to access printer.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _initializeBluetoothFlow,
                    child: const Text('Grant'),
                  ),
                ],
              ),
            ),
          const Text('Receipt Settings'),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paper Width:'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<PaperSize>(
                  segments: const [
                    ButtonSegment<PaperSize>(
                      value: PaperSize.mm58,
                      label: Text('58mm'),
                    ),
                    ButtonSegment<PaperSize>(
                      value: PaperSize.mm80,
                      label: Text('80mm'),
                    ),
                  ],
                  selected: {_selectedPaperSize},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedPaperSize = selection.first;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _storeNameController,
            onChanged: (_) => _saveReceiptSettings(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Store Header (required)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _storeAddressController,
            onChanged: (_) => _saveReceiptSettings(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Store Address',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bookingWhatsappController,
            onChanged: (_) => _saveReceiptSettings(),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'WhatsApp Number (for booking info)',
              hintText: 'e.g. 0812xxxxxxx',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _wifiNameController,
            onChanged: (_) => _saveReceiptSettings(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'WiFi Name (optional)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _wifiPasswordController,
            onChanged: (_) => _saveReceiptSettings(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'WiFi Password (optional)',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<BluetoothInfo>(
            isExpanded: true,
            value: _resolveBluetoothSelection(_selectedPrinter, _pairedDevices),
            items: _pairedDevices
                .map(
                  (d) => DropdownMenuItem<BluetoothInfo>(
                    value: d,
                    child: Text(
                      '${d.name} (${d.macAdress})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            selectedItemBuilder: (context) => _pairedDevices
                .map(
                  (d) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${d.name} (${d.macAdress})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedPrinter = value),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Paired printer',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isPrinterConnected ? null : _connectPrinter,
                  child: const Text('Connect'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isPrinterConnected ? _disconnectPrinter : null,
                  child: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ] else ...[
          if (_isUsbScanInProgress)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          DropdownButtonFormField<thermal.PrinterDevice>(
            isExpanded: true,
            value: _resolveUsbSelection(_selectedUsbPrinter, _usbDevices),
            items: _usbDevices
                .map(
                  (device) => DropdownMenuItem<thermal.PrinterDevice>(
                    value: device,
                    child: Text(
                      '${device.name} (VID:${device.vendorId ?? '-'} PID:${device.productId ?? '-'})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedUsbPrinter = value),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'USB printer',
            ),
          ),
          if (_usbDevices.isEmpty && !_isUsbScanInProgress)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No USB printer detected. Connect via OTG, power on printer, then tap Scan USB.',
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _refreshUsbPrinters,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan USB'),
              ),
              FilledButton(
                onPressed: _isUsbPrinterConnected ? null : _connectUsbPrinter,
                child: const Text('Connect USB'),
              ),
              OutlinedButton(
                onPressed: _isUsbPrinterConnected
                    ? () => _disconnectUsbPrinter()
                    : null,
                child: const Text('Disconnect USB'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'USB Debug',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text('Discovered devices: ${_usbDevices.length}'),
                  Text(
                    'Selected: ${_selectedUsbPrinter == null ? '-' : '${_selectedUsbPrinter!.name} | VID:${_selectedUsbPrinter!.vendorId ?? '-'} PID:${_selectedUsbPrinter!.productId ?? '-'}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Last scan: ${_formatDebugTime(_lastUsbScanAt)}'),
                  Text(
                    'Scan error: ${_lastUsbDiscoveryError == null || _lastUsbDiscoveryError!.isEmpty ? '-' : _lastUsbDiscoveryError!}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Last connect: ${_formatDebugTime(_lastUsbConnectAt)}'),
                  Text(
                    'Connect error: ${_lastUsbConnectError == null || _lastUsbConnectError!.isEmpty ? '-' : _lastUsbConnectError!}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Last print: ${_formatDebugTime(_lastUsbPrintAt)}'),
                  Text(
                    'Print status: ${_lastUsbPrintSuccess == null ? '-' : (_lastUsbPrintSuccess! ? 'SUCCESS' : 'FAILED')}',
                  ),
                  Text(
                    'Print error: ${_lastUsbPrintError == null || _lastUsbPrintError!.isEmpty ? '-' : _lastUsbPrintError!}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 4),
        const Text('Catalog Defaults'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _resetCatalogToBundledMenu,
          icon: const Icon(Icons.restore),
          label: const Text('Reset Catalog to Default Menu'),
        ),
      ],
    );
  }

  Widget _buildSyncExportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sync Exports (CSV)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Refresh exports',
              onPressed: _loadSyncCsvHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_syncCsvHistory.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No CSV exports yet. Sync transactions first to generate files.',
              ),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _syncCsvHistory.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final filePath = _syncCsvHistory[index];
                final fileName = File(filePath).uri.pathSegments.last;
                return ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    filePath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Share CSV',
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => _shareSavedCsvExport(filePath),
                      ),
                      IconButton(
                        tooltip: 'Delete CSV',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteSavedCsvExport(filePath),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCatalogTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Product Catalog (saved locally)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Product name',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _productPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Price',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedProductCategory,
          items: _productCategories
              .map(
                (category) => DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedProductCategory = value;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Category',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _addProductToCatalog,
            child: const Text('Save Product'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 420,
          child: Card(
            child: _catalogProducts.isEmpty
                ? const Center(child: Text('No saved products yet'))
                : ListView.builder(
                    itemCount: _catalogProducts.length,
                    itemBuilder: (context, index) {
                      final product = _catalogProducts[index];
                      return ListTile(
                        selected: _selectedCatalogProduct?.id == product.id,
                        onTap: () {
                          setState(() {
                            _selectedCatalogProduct = product;
                          });
                        },
                        title: Text(product.name),
                        subtitle:
                            Text('${product.category} • Rp${product.price}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit product',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editProductInCatalog(product),
                            ),
                            IconButton(
                              tooltip: 'Delete product',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _removeProductFromCatalog(product.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _addPromoConfig() {
    final productId = _promoFormProductId;
    if (_promoFormType != _PromoType.buy1Get1CrossProduct &&
        _promoFormType != _PromoType.percentageCategory &&
        (productId == null || productId.isEmpty)) {
      _showMessage('Select product for promo first.');
      return;
    }

    if (_promoFormType == _PromoType.percentageProduct ||
        _promoFormType == _PromoType.percentageCategory) {
      final discountPercent =
          int.tryParse(_promoDiscountPercentController.text.trim());
      if (discountPercent == null ||
          discountPercent <= 0 ||
          discountPercent > 100) {
        _showMessage('Discount percent must be between 1 and 100.');
        return;
      }

      if (_promoFormType == _PromoType.percentageCategory) {
        final promo = _PromoConfig(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: _PromoType.percentageCategory,
          productId: '*',
          discountPercent: discountPercent,
          categoryScope: _selectedPromoCategory,
        );

        setState(() {
          _promoConfigs = [promo, ..._promoConfigs];
        });
        _savePromoConfigs();
        _showMessage('Category percentage promo saved.');
        return;
      }

      final promo = _PromoConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _PromoType.percentageProduct,
        productId: productId!,
        discountPercent: discountPercent,
      );

      setState(() {
        _promoConfigs = [promo, ..._promoConfigs];
      });
      _savePromoConfigs();
      _showMessage('Percentage promo saved.');
      return;
    }

    final promo = _PromoConfig(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _PromoType.buy1Get1,
      productId: productId!,
      discountPercent: 0,
    );

    if (_promoFormType == _PromoType.buy1Get1CrossProduct) {
      final crossPromo = _PromoConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _PromoType.buy1Get1CrossProduct,
        productId: '*',
        discountPercent: 0,
        categoryScope: _selectedPromoCategory,
      );

      setState(() {
        _promoConfigs = [crossPromo, ..._promoConfigs];
      });
      _savePromoConfigs();
      _showMessage('Cross-product Buy 1 Get 1 promo saved.');
      return;
    }

    setState(() {
      _promoConfigs = [promo, ..._promoConfigs];
    });
    _savePromoConfigs();
    _showMessage('Buy 1 Get 1 promo saved.');
  }

  Future<void> _deletePromoConfig(String promoId) async {
    setState(() {
      _promoConfigs.removeWhere((promo) => promo.id == promoId);
      if (_selectedPromoConfigId == promoId) {
        _selectedPromoConfigId = null;
      }
    });
    await _savePromoConfigs();
  }

  Widget _buildPromoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Promo Settings'),
        const SizedBox(height: 8),
        SegmentedButton<_PromoType>(
          segments: const [
            ButtonSegment<_PromoType>(
              value: _PromoType.percentageProduct,
              label: Text('% Product'),
            ),
            ButtonSegment<_PromoType>(
              value: _PromoType.percentageCategory,
              label: Text('% Category'),
            ),
            ButtonSegment<_PromoType>(
              value: _PromoType.buy1Get1,
              label: Text('Buy 1 Get 1'),
            ),
            ButtonSegment<_PromoType>(
              value: _PromoType.buy1Get1CrossProduct,
              label: Text('Cross Product B1G1'),
            ),
          ],
          selected: {_promoFormType},
          onSelectionChanged: (selection) {
            setState(() {
              _promoFormType = selection.first;
            });
          },
        ),
        const SizedBox(height: 8),
        if (_promoFormType == _PromoType.percentageCategory ||
            _promoFormType == _PromoType.buy1Get1CrossProduct)
          DropdownButtonFormField<String>(
            value: _selectedPromoCategory,
            items: _productCategories
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedPromoCategory = value;
              });
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Category scope',
            ),
          ),
        if (_promoFormType != _PromoType.buy1Get1CrossProduct &&
            _promoFormType != _PromoType.percentageCategory)
          DropdownButtonFormField<String>(
            value: _promoFormProductId,
            items: _catalogProducts
                .map(
                  (product) => DropdownMenuItem<String>(
                    value: product.id,
                    child: Text('${product.name} (Rp${product.price})'),
                  ),
                )
                .toList(),
            onChanged: _catalogProducts.isEmpty
                ? null
                : (value) {
                    setState(() {
                      _promoFormProductId = value;
                    });
                  },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Promo product',
            ),
          ),
        if (_promoFormType == _PromoType.buy1Get1CrossProduct)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: Text(
                  'Cross Product B1G1 applies only to items in category: $_selectedPromoCategory. Discount is taken from the lowest-priced eligible items.',
                ),
              ),
            ],
          ),
        if (_promoFormType == _PromoType.percentageProduct ||
            _promoFormType == _PromoType.percentageCategory) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _promoDiscountPercentController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Discount %',
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _catalogProducts.isEmpty ? null : _addPromoConfig,
            child: const Text('Save Promo'),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Saved promos'),
        const SizedBox(height: 8),
        Card(
          child: _promoConfigs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No promo configured yet')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _promoConfigs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final promo = _promoConfigs[index];
                    return ListTile(
                      title: Text(_promoDisplayLabel(promo)),
                      subtitle: Text('Type: ${promo.type.code}'),
                      trailing: IconButton(
                        tooltip: 'Delete promo',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deletePromoConfig(promo.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBarTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Incoming orders for bartender'),
        const SizedBox(height: 8),
        if (_incomingOrders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No incoming orders yet.'),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _incomingOrders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final order = _incomingOrders[index];
                final isIncoming = order.isIncoming;
                final isOnProgress = order.isOnProgress;
                final isFinished = order.isFinished;

                final statusLabel = isFinished
                    ? 'Finished'
                    : (isOnProgress ? 'On-Progress' : 'Incoming');
                final statusColor = isFinished
                    ? Colors.green.shade700
                    : (isOnProgress
                        ? Colors.blue.shade700
                        : Colors.orange.shade700);
                final statusBackground = isFinished
                    ? Colors.green.shade50
                    : (isOnProgress
                        ? Colors.blue.shade50
                        : Colors.orange.shade50);
                final actionLabel = isIncoming
                    ? 'Start'
                    : (isOnProgress ? 'Finish' : 'Finished');
                final itemDetails = order.items;
                return ListTile(
                  title: Text(
                    'Order #${order.orderNumber} - ${order.customerName}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Items: ${order.itemCount} | Total: Rp${order.total}'),
                      if (itemDetails.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...itemDetails.map((item) {
                          final noteText = item.note.trim();
                          final itemText = noteText.isEmpty
                              ? '- ${item.quantity}x ${item.name}'
                              : '- ${item.quantity}x ${item.name} ($noteText)';
                          return Text(
                            itemText,
                            style: const TextStyle(fontSize: 12),
                          );
                        }),
                      ],
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: FilledButton.tonal(
                    onPressed:
                        isFinished ? null : () => _advanceBarOrderStatus(order),
                    child: Text(actionLabel),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSalesTab() {
    final pricingSummary = _currentPricingSummary;
    final promoBreakdownNotes =
        _buildPromoFreeItemNotes(_items, _selectedPromoConfig);
    final filteredCatalogProducts = _filteredCatalogProducts;
    final selectedCatalogProductValue = filteredCatalogProducts.any(
      (product) => product.id == _selectedCatalogProduct?.id,
    )
        ? _selectedCatalogProduct
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Add sale item from saved products'),
        const SizedBox(height: 8),
        TextField(
          controller: _catalogSearchController,
          onChanged: (value) {
            setState(() {
              _catalogSearchQuery = value;
            });
          },
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Search product (%value%)',
            hintText: 'Name / category / price',
            suffixIcon: _catalogSearchQuery.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      setState(() {
                        _catalogSearchController.clear();
                        _catalogSearchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Product>(
          isExpanded: true,
          value: selectedCatalogProductValue,
          items: filteredCatalogProducts
              .map(
                (product) => DropdownMenuItem<Product>(
                  value: product,
                  child: Text(
                    '${product.name} (${product.category}) - Rp${product.price}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => filteredCatalogProducts
              .map(
                (product) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${product.name} (${product.category}) - Rp${product.price}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCatalogProduct = value;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Select product',
          ),
        ),
        if (_catalogSearchQuery.trim().isNotEmpty &&
            filteredCatalogProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No product matches "${_catalogSearchQuery.trim()}".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _saleQtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Qty',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _saleItemNoteController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Item Note (optional)',
            hintText: 'e.g. Less sugar / no ice',
          ),
        ),
        const SizedBox(height: 8),
        const Text('Cart items'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedPromoDropdownValue,
          items: [
            const DropdownMenuItem<String>(
              value: 'none',
              child: Text(
                'No Promo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ..._promoConfigs.map(
              (promo) => DropdownMenuItem<String>(
                value: promo.id,
                child: Text(
                  _promoSalesDropdownLabel(promo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          selectedItemBuilder: (context) {
            return [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No Promo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._promoConfigs.map(
                (promo) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _promoSalesDropdownLabel(promo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ];
          },
          onChanged: (value) {
            setState(() {
              _selectedPromoConfigId =
                  value == null || value == 'none' ? null : value;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Apply Promo',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPaymentMethod,
          items: _paymentMethods
              .map(
                (method) => DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedPaymentMethod = value;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Payment Method',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _addSelectedProductToCart,
          child: const Text('Add to Cart'),
        ),
        const SizedBox(height: 8),
        Card(
          child: _items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No items yet')),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        item.note.trim().isEmpty
                            ? '${item.quantity} x ${item.unitPrice}'
                            : '${item.quantity} x ${item.unitPrice}\nNote: ${item.note.trim()}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Rp${item.total}'),
                          IconButton(
                            tooltip: 'Remove item',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeCartItem(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Subtotal: Rp${pricingSummary.grossSubtotal}'),
                if (pricingSummary.promoLabel.isNotEmpty)
                  Text('Promo: ${pricingSummary.promoLabel}'),
                if (promoBreakdownNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...promoBreakdownNotes.map(
                    (note) => Text(
                      note,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                Text('Discount: Rp${pricingSummary.discountAmount}'),
                const Divider(),
                Text(
                  'Total: Rp${pricingSummary.netSubtotal}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _customerNameController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Customer Name',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _orderNumberController,
          readOnly: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Order Number (Auto)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _showReceiptPreview,
          icon: const Icon(Icons.print),
          label: const Text('Preview & Print'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Simple Bluetooth POS'),
          actions: [
            TextButton.icon(
              onPressed: _syncTransactionsByEmail,
              icon: const Icon(Icons.sync),
              label: Text('Sync ($_pendingSyncCount)'),
            ),
          ],
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _currentTabIndex = index;
              });
            },
            tabs: const [
              Tab(text: 'Settings', icon: Icon(Icons.settings)),
              Tab(text: 'Sync Exports', icon: Icon(Icons.table_chart_outlined)),
              Tab(text: 'Catalog', icon: Icon(Icons.inventory_2_outlined)),
              Tab(text: 'Promo', icon: Icon(Icons.discount_outlined)),
              Tab(text: 'Sales', icon: Icon(Icons.point_of_sale)),
              Tab(text: 'Bar', icon: Icon(Icons.local_bar_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSettingsTab(),
            _buildSyncExportsTab(),
            _buildCatalogTab(),
            _buildPromoTab(),
            _buildSalesTab(),
            _buildBarTab(),
          ],
        ),
        floatingActionButton: _currentTabIndex == 0
            ? FloatingActionButton.extended(
                onPressed: _loadPairedPrinters,
                label: const Text('Refresh Printers'),
                icon: const Icon(Icons.refresh),
              )
            : null,
      ),
    );
  }
}

enum _PrinterConnectionMode { bluetooth, usb }

extension on _PrinterConnectionMode {
  String get code {
    switch (this) {
      case _PrinterConnectionMode.bluetooth:
        return 'bluetooth';
      case _PrinterConnectionMode.usb:
        return 'usb';
    }
  }
}

enum _PrinterType { invoice, label }

extension on _PrinterType {
  String get code {
    switch (this) {
      case _PrinterType.invoice:
        return 'invoice';
      case _PrinterType.label:
        return 'label';
    }
  }
}

enum _PromoType {
  percentageProduct,
  percentageCategory,
  buy1Get1,
  buy1Get1CrossProduct,
}

extension on _PromoType {
  String get code {
    switch (this) {
      case _PromoType.percentageProduct:
        return 'percentage';
      case _PromoType.percentageCategory:
        return 'percentage_category';
      case _PromoType.buy1Get1:
        return 'buy1get1';
      case _PromoType.buy1Get1CrossProduct:
        return 'buy1get1_cross';
    }
  }
}

_PromoType _promoTypeFromCode(String code) {
  switch (code) {
    case 'percentage':
      return _PromoType.percentageProduct;
    case 'percentage_category':
      return _PromoType.percentageCategory;
    case 'buy1get1':
      return _PromoType.buy1Get1;
    case 'buy1get1_cross':
      return _PromoType.buy1Get1CrossProduct;
    default:
      return _PromoType.percentageProduct;
  }
}

class _PromoConfig {
  const _PromoConfig({
    required this.id,
    required this.type,
    required this.productId,
    required this.discountPercent,
    this.categoryScope = '',
  });

  final String id;
  final _PromoType type;
  final String productId;
  final int discountPercent;
  final String categoryScope;

  factory _PromoConfig.fromJson(Map<String, dynamic> json) {
    final discount = json['discountPercent'];
    return _PromoConfig(
      id: (json['id'] ?? '').toString(),
      type: _promoTypeFromCode((json['type'] ?? '').toString()),
      productId: (json['productId'] ?? '').toString(),
      discountPercent: discount is int
          ? discount
          : int.tryParse((discount ?? '').toString()) ?? 0,
      categoryScope: (json['categoryScope'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.code,
      'productId': productId,
      'discountPercent': discountPercent,
      'categoryScope': categoryScope,
    };
  }
}

class _PromoUnit {
  const _PromoUnit({
    required this.name,
    required this.price,
  });

  final String name;
  final int price;
}

class _PricingSummary {
  const _PricingSummary({
    required this.grossSubtotal,
    required this.discountAmount,
    required this.netSubtotal,
    required this.promoType,
    required this.promoLabel,
  });

  final int grossSubtotal;
  final int discountAmount;
  final int netSubtotal;
  final String promoType;
  final String promoLabel;
}
