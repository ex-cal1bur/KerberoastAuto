# KerberoastAuto

A Bash script to **automate Kerberoasting attacks**, handling `faketime` synchronization and leveraging Impacket to extract Service Principal Name (SPN) hashes from Active Directory.

---

## Purpose
This script automates the full Kerberoasting attack chain. It handles crucial steps like time synchronization with the Domain Controller (DC), obtaining a Kerberos Ticket Granting Ticket (TGT), and then extracting Service Principal Name (SPN) hashes. This makes the process more efficient and reliable for penetration testers.

---

## Usage

1.  **Save the script**: Copy the content into a `.sh` file (e.g., `kerberoast_auto.sh`).
2.  **Make it executable**:
    ```bash
    chmod +x kerberoast_auto.sh
    ```
3.  **Run the script**: It'll prompt you for necessary details.
    ```bash
    ./kerberoast_auto.sh
    ```

---

## Output

If successful, the script creates a `kerberoast.hashes` file in the same directory. This file will contain the extracted SPN hashes, ready for offline cracking with tools like Hashcat or John the Ripper.

---
