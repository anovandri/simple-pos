# Dual Bluetooth Printer UI Implementation

## Overview
The POS app now supports **two independent Bluetooth thermal printers**:
- **Invoice Printer** - For printing customer receipts/invoices
- **Label Printer** - For printing bar/kitchen order labels

## What Was Changed

### 1. Settings UI Updated (`_buildSettingsTab()`)
The Settings tab now displays **two separate printer configuration sections** instead of one:

#### Invoice Printer Section (Blue Card)
- 🔵 Blue-themed card with receipt icon
- Dropdown to select invoice printer from paired Bluetooth devices
- Connect/Disconnect buttons
- Real-time connection status indicator (green = connected, gray = disconnected)

#### Label Printer Section (Orange Card)
- 🟠 Orange-themed card with label icon  
- Dropdown to select label printer from paired Bluetooth devices
- Connect/Disconnect buttons
- Real-time connection status indicator (green = connected, gray = disconnected)

### 2. Backend Integration
The UI is now connected to the dual-Bluetooth infrastructure:
- Uses `_invoiceBluetoothConnection` and `_labelBluetoothConnection` states
- Calls `_connectBluetoothPrinter(_PrinterType.invoice)` for invoice printer
- Calls `_connectBluetoothPrinter(_PrinterType.label)` for label printer
- Shows real connection status via `_isBluetoothConnected(printerType)`

### 3. Device List Population
Updated `_loadPairedPrinters()` to populate both:
- `_invoicePairedDevices` - Available devices for invoice printer
- `_labelPairedDevices` - Available devices for label printer
- Both lists show the same paired Bluetooth devices (user can select different printers for each role)

## How to Use

### Step 1: Grant Bluetooth Permission
1. Go to **Settings** tab
2. If prompted, tap **"Grant"** to enable Bluetooth permission
3. Approve "Nearby devices" permission when Android prompts

### Step 2: Configure Invoice Printer
1. In the **Invoice Printer** (blue) section:
   - Select your receipt printer from the dropdown
   - Tap **"Connect"**
   - Wait for status to show "Connected" (green)

### Step 3: Configure Label Printer
1. In the **Label Printer** (orange) section:
   - Select your label/kitchen printer from the dropdown
   - Tap **"Connect"**
   - Wait for status to show "Connected" (green)

### Step 4: Test Printing
- **Print Invoice**: Print a receipt from the Orders tab → Both invoice and label print simultaneously
- **Kitchen Label**: When advancing bar order status → Prints to label printer only

## Technical Details

### Connection Management
- Each printer maintains its own **independent Bluetooth socket** (`BluetoothConnection`)
- Both printers can be connected **simultaneously** (no disconnect/reconnect needed)
- Auto-reconnect logic handles connection failures gracefully

### Printer Type Routing
- `_printReceipt()` → Routes to **Invoice Printer** (`_PrinterType.invoice`)
- `_advanceBarOrderStatus()` → Routes to **Label Printer** (`_PrinterType.label`)
- `_writeBytesWithRecovery()` handles type-aware writing to correct printer

### UI Features
- **Color-coded cards**: Blue = Invoice, Orange = Label/Kitchen
- **Real-time status**: Connection state updates immediately
- **Independent controls**: Each printer has its own Connect/Disconnect buttons
- **Visual feedback**: Green badge when connected, gray when disconnected

## Testing Status
✅ All tests passed  
✅ Code compiles without errors  
✅ Only expected lint warnings (unused legacy fields)

## Next Steps for User
1. **Physical Setup**: 
   - Pair both thermal printers with your Android device via system Bluetooth settings
   - Power on both printers
   
2. **App Configuration**:
   - Open the app → Go to Settings tab
   - Grant Bluetooth permission
   - Configure both printers as described above

3. **Verify**:
   - Print a test invoice → Check if it prints to the invoice printer
   - Advance a bar order → Check if label prints to the label printer

## Troubleshooting

### "No devices shown in dropdown"
- Make sure Bluetooth printers are **paired** in Android Settings → Bluetooth
- Tap "Grant" button to enable Bluetooth permission
- Restart the app

### "Connection fails"
- Ensure printer is powered on
- Check printer is within Bluetooth range
- Try disconnecting and reconnecting
- Restart printer if needed

### "Both print to same printer"
- Check you selected **different printers** in invoice vs label dropdowns
- Disconnect one printer, change selection, then reconnect

## Benefits of This Implementation
✅ **Simultaneous printing** - No waiting for disconnect/reconnect  
✅ **Clear separation** - Invoice vs Kitchen/Bar labels  
✅ **Independent control** - Connect/disconnect each printer separately  
✅ **Visual clarity** - Color-coded UI makes it easy to distinguish printers  
✅ **Flexible setup** - Can use same printer for both roles if needed (just select it in both dropdowns)
