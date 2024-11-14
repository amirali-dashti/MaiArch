import os
os.system('ls')

def ButtonWindow(text):
    os.system(f'dialog --msgbox  "{text}" 10 25')
    
def OptionWindow(text, options):
    options = str()
    for i in range(0, len(options)):
        options += f"{i} '{options[i]}' "
    print(options)
    os.system(f"dialog --menu “{text}” 12 45 25 {options}")
    


OptionWindow("choose between these GUIs", ["KDE plasma", "XFCE4", "GNOME"])