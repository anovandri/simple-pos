# Dual Thermal Printer Architecture

## Overview

Your POS application now supports two independent thermal printers:
- **Invoice Printer**: Prints customer receipts
- **Label Printer**: Prints kitchen/bar order labels

This allows simultaneous operation of two printers without mode switching.

## Architecture Components

### 1. PrinterType Enum

```dart
enum _PrinterType { invoice, label }
```

Identifies which printer type an operation targets.

### 2. Dual Printer State Variables

Each printer type maintains independent state:

#### Invoice Printer
- `_invoicePairedDevices`: List of paired Bluetooth devices for invoices
- `_invoiceSelectedPrinter`: Currently selected Bluetooth invoice printer
- `_invoiceUsbDevices`: List of discovered USB devices for invoices
- `_invoiceSelectedUsbPrinter`: Currently selected USB invoice printer
- `_invoicePrinterConnectionMode`: Connection type (Bluetooth or USB)
- `_isInvoicePrinterConnected`: Bluetooth connection status
- `_isInvoiceUsbPrinterConnected`: USB connection status
- `_invoiceUsbNeedsRecoveryAfterResume`: USB recovery flag after suspend

#### Label Printer
- `_labelPairedDevices`: List of paired Bluetooth devices for labels
- `_labelSelectedPrinter`: Currently selected Bluetooth label printer
- `_labelUsbDevices`: List of discovered USB devices for labels
- `_labelSelectedUsbPrinter`: Currently selected USB label printer
- `_labelPrinterConnectionMode`: Connection type (Bluetooth or USB)
- `_isLabelPrinterConnected`: Bluetooth connection status
- `_isLabelUsbPrinterConnected`: USB connection status
- `_labelUsbNeedsRecoveryAfterResume`: USB recovery flag after suspend

### 3. Helper Accessor Methods

Simplify state access based on printer type:

```dart
// Getters for printer state
BluetoothInfo? _selectedPrinterForType(_PrinterType printerType)
thermal.PrinterDevice? _selectedUsbPrinterForType(_PrinterType printerType)
_PrinterConnectionMode _printerModeForType(_PrinterType printerType)
bool _isBtConnectedForType(_PrinterType printerType)
bool _isUsbConnectedForType(_PrinterType printerType)
List<BluetoothInfo> _btDevicesForType(_PrinterType printerType)
List<thermal.PrinterDevice> _usbDevicesForType(_PrinterType printerType)

// Setters for printer state
void _setSelectedBtPrinter(_PrinterType printerType, BluetoothInfo? printer)
void _setSelectedUsbPrinter(_PrinterType printerType, thermal.PrinterDevice? printer)
void _setBtConnected(_PrinterType printerType, bool value)
void _setUsbConnected(_PrinterType printerType, bool value)
void _setPrinterMode(_PrinterType printerType, _PrinterConnectionMode mode)
void _setUsbNeedsRecovery(_PrinterType printerType, bool value)
```

### 4. Refactored _writeBytesWithRecovery

Now supports printer type parameter:

```dart
Future<bool> _writeBytesWithRecovery(
  List<int> bytes, {
  _PrinterType printerType = _PrinterType.invoice,
}) async
```

**Usage in Receipt Printing**:
```dart
final result = await _writeBytesWithRecovery(bytes,
    printerType: _PrinterType.invoice);
```

**Usage in Label Printing**:
```dart
final result = await _writeBytesWithRecovery(bytes,
    printerType: _PrinterType.label);
```

## Current Limitations

### Bluetooth

The `PrintBluetoothThermal` library manages a single global Bluetooth connection. For true dual-printer Bluetooth support, you would need:

1. **Native platform code** (Kotlin for Android, Swift for iOS) to manage multiple simultaneous Bluetooth connections
2. **Custom plugin** wrapping the platform-specific Bluetooth APIs
3. **Alternative library** supporting multiple concurrent connections

**Current implementation**: Both invoice and label printers can be configured, but only one Bluetooth connection is active at a time. USB printers are fully independent.

### USB

USB printers are fully independent and can be used simultaneously - one configured as invoice, one as label.

## Implementation Next Steps

To complete dual-printer functionality:

### 1. **Printer Selection UI**
Add Settings tab controls for:
- Invoice printer Bluetooth/USB selection
- Label printer Bluetooth/USB selection
- Separate connection status indicators

### 2. **Type-Specific Connection Methods**
Create parallel methods for each printer type:
```dart
Future<bool> _ensureInvoicePrinterReady()
Future<bool> _ensureLabelPrinterReady()
Future<void> _connectInvoicePrinter()
Future<void> _connectLabelPrinter()
// etc.
```

### 3. **Mode-Switching for Bluetooth**
If using Bluetooth for both printers, implement:
```dart
Future<void> _switchBluetoothPrinterForType(_PrinterType targetType)
```

### 4. **Error Handling**
Enhance error messages to specify which printer failed:
```dart
_showMessage('Invoice printer not ready. Please reconnect.');
_showMessage('Label printer not ready. Please reconnect.');
```

### 5. **Persistence**
Save printer preferences using existing keys:
```dart
static const _invoicePrinterModeKey = 'invoice_printer_connection_mode';
static const _labelPrinterModeKey = 'label_printer_connection_mode';
```

## File Structure

All changes are contained in:
- **`lib/main.dart`**: 
  - Lines 74-75: Storage keys
  - Lines 109-128: State variables
  - Lines 196-273: Helper accessor methods
  - Line 3816: `_PrinterType` enum definition
  - Lines 2135-2231: Refactored `_writeBytesWithRecovery`
  - Lines 1916-1917: Invoice printer write call
  - Lines 2115-2116: Label printer write call

## Testing Status

✅ **Compilation**: Passes `flutter analyze`
✅ **Unit Tests**: All 4 tests pass
⏳ **On-Device Testing**: Pending manual validation with actual printers

## Usage Example

```dart
// Invoice printing (existing code with printer type specified)
final result = await _writeBytesWithRecovery(bytes,
    printerType: _PrinterType.invoice);

// Label printing (existing code with printer type specified)
final result = await _writeBytesWithRecovery(bytes,
    printerType: _PrinterType.label);

// Query printer state
final invoiceReady = _isBtConnectedForType(_PrinterType.invoice);
final labelReady = _isUsbConnectedForType(_PrinterType.label);

// Update printer state
setState(() {
  _setSelectedBtPrinter(_PrinterType.invoice, selectedDevice);
  _setBtConnected(_PrinterType.invoice, true);
});
```

## Legacy Compatibility

The original single-printer variables remain:
- `_pairedDevices`, `_selectedPrinter`, `_printerConnectionMode`, etc.

These are kept for backward compatibility and can be gradually phased out as new printer-specific methods are implemented.

## Future Enhancements

1. **Hardware detection**: Auto-select optimal printer (invoice/label) based on capability
2. **Fallback support**: Print to alternative printer if primary unavailable
3. **Concurrent printing**: Queue documents and print to both printers in parallel
4. **Printer profiles**: Save different receipt formats per printer type
5. **Print statistics**: Track successful prints per printer type
