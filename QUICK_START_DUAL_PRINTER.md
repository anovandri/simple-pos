# ⚡ Quick Start: Dual Bluetooth Printer Setup

## 📋 Prerequisites
- [ ] Android device with Bluetooth
- [ ] 2 thermal printers (or 1 if using same printer for both)
- [ ] Printers are paired in Android Settings → Bluetooth

## 🚀 5-Minute Setup Guide

### Step 1: Pair Printers (In Android Settings)
```
Android Settings → Bluetooth → Pair new device
→ Power on Printer 1 (Invoice) → Tap to pair
→ Power on Printer 2 (Label) → Tap to pair
```

### Step 2: Open POS App Settings
```
POS App → Bottom Tab "Settings" → Scroll down
```

### Step 3: Grant Bluetooth Permission
```
Tap "Grant" button → Allow "Nearby devices" → Done
```

### Step 4: Configure Invoice Printer (Blue Card 🔵)
```
1. Tap dropdown "Select invoice printer"
2. Choose your receipt printer (e.g., "EPSON TM-T20")
3. Tap "Connect" button
4. Wait for green "Connected" status ✅
```

### Step 5: Configure Label Printer (Orange Card 🟠)
```
1. Tap dropdown "Select label printer"  
2. Choose your kitchen/bar printer (e.g., "Bixolon SRP")
3. Tap "Connect" button
4. Wait for green "Connected" status ✅
```

### Step 6: Test Printing
```
Go to Orders tab → Complete an order → Print
→ Invoice printer: Prints receipt ✅
→ Label printer: Prints kitchen ticket ✅
```

## 🎯 Visual Guide

```
┌──────────────────────────────────────┐
│  SETTINGS TAB                        │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ 🧾 INVOICE PRINTER      [BLUE] │ │
│  │────────────────────────────────│ │
│  │ Dropdown: [Epson TM-T20 ▼]     │ │
│  │ [Connect] [Disconnect]          │ │
│  │ Status: ● Connected             │ │
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ 🏷️  LABEL PRINTER    [ORANGE]  │ │
│  │────────────────────────────────│ │
│  │ Dropdown: [Bixolon SRP ▼]      │ │
│  │ [Connect] [Disconnect]          │ │
│  │ Status: ● Connected             │ │
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘
```

## ❓ Troubleshooting

### Problem: "No devices in dropdown"
**Solution:** 
1. Go to Android Settings → Bluetooth
2. Pair both printers
3. Return to app → Tap "Grant" permission button
4. Printers should appear in dropdown

### Problem: "Connection failed"
**Solution:**
1. Check printer is powered ON
2. Check printer Bluetooth is enabled
3. Try: Disconnect → Wait 3 seconds → Connect again
4. If still fails: Restart printer

### Problem: "Print doesn't work"
**Solution:**
1. Check both printers show "● Connected" (green)
2. Test print from printer's self-test function
3. Verify printer has paper loaded
4. Check printer isn't in error state (paper jam, cover open)

### Problem: "Both print to same printer"
**Solution:**
- You probably selected the same printer in both dropdowns!
- Solution: In orange card (Label Printer), choose a **different** printer

### Problem: "Want to use same printer for both"
**Answer:**
- That's totally fine! 
- Just select the same printer in both invoice AND label dropdowns
- Both receipts and labels will print to that one printer

## 💡 Pro Tips

### Tip 1: Label Both Printers
```
Use label maker or stickers:
Printer 1: "📄 INVOICE - Front Counter"
Printer 2: "🏷️  LABELS - Kitchen/Bar"
```

### Tip 2: Keep Printers Powered On
```
Bluetooth connection is faster when printers are always on.
If printer auto-sleeps, consider disabling sleep mode.
```

### Tip 3: Position Printers Strategically
```
Invoice Printer: Near cashier (for customer receipts)
Label Printer: Near kitchen/bar (for order preparation)
```

### Tip 4: Use Different Paper Widths
```
Invoice: 80mm thermal paper (wider, professional receipts)
Label: 58mm thermal paper (compact, kitchen tickets)
```

### Tip 5: Test Before Busy Hours
```
Connect both printers during setup/training time.
Print test orders to verify everything works.
Don't wait until you have a line of customers!
```

## 📊 Performance Comparison

| Scenario                  | Single Printer | Dual Printer |
|---------------------------|----------------|--------------|
| Print 1 invoice           | ~2 seconds     | ~2 seconds   |
| Print 1 invoice + 1 label | ~6.5 seconds*  | ~2 seconds** |
| Print 10 orders (rush)    | ~65 seconds    | ~20 seconds  |

*With disconnect/reconnect overhead  
**Simultaneous printing (parallel)

## ✅ Success Checklist

After setup, you should see:
- [✅] Both printers show "● Connected" (green status)
- [✅] Different printers selected in blue vs orange cards
- [✅] Test invoice prints correctly
- [✅] Test label prints correctly
- [✅] Both print simultaneously when completing orders

## 📞 Need Help?

**Common Issues:**
- Bluetooth permission → Grant via "Grant" button
- Printer not found → Pair in Android Settings first
- Connection drops → Check Bluetooth range (<10 meters)
- Slow printing → Make sure both printers connected (no reconnection overhead)

**File Issues/Bugs:**
- GitHub: anovandri/simple-pos
- Check existing issues or create new one
- Include: Android version, printer model, error screenshot

## 🎉 You're All Set!

Your POS system can now:
✅ Print invoices to front counter printer  
✅ Print kitchen/bar labels to back-of-house printer  
✅ Both print simultaneously (super fast!)  
✅ No more manual sorting of receipts  
✅ Streamlined kitchen workflow  

**Enjoy your upgraded POS system! 🚀**
