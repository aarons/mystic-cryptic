import tkinter as tk
from tkinter import filedialog, messagebox
import subprocess

def backup():
    dir_to_backup = filedialog.askdirectory()
    result = subprocess.run(['./backup.sh', dir_to_backup])
    
    if result.returncode == 0:
        messagebox.showinfo("Success", "Backup completed successfully.")
    else:
        messagebox.showerror("Error", "An error occurred during backup.")

def restore():
    backup_file = filedialog.askopenfilename()
    result = subprocess.run(['./restore.sh', backup_file])
    
    if result.returncode == 0:
        messagebox.showinfo("Success", "Restore completed successfully.")
    else:
        messagebox.showerror("Error", "An error occurred during restore.")

root = tk.Tk()

# Define window size
window_width = 300
window_height = 200

# Get screen width and height
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()

# Calculate position coordinates
position_top = int(screen_height / 2 - window_height / 2)
position_right = int(screen_width / 2 - window_width / 2)

# Set the position and size of the window
root.geometry(f"{window_width}x{window_height}+{position_right}+{position_top}")

backup_button = tk.Button(root, text="Backup", command=backup)
backup_button.pack(fill='both', expand=True)

restore_button = tk.Button(root, text="Restore", command=restore)
restore_button.pack(fill='both', expand=True)

root.mainloop()
