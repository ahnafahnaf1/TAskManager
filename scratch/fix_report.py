with open('lib/screens/report_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(
    ': "$_overdueCount Overdue Task" + (_overdueCount > 1 ? "s" : ""),',
    ': \'$_overdueCount Overdue Task${_overdueCount > 1 ? "s" : ""}\','
)

with open('lib/screens/report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print('FIXED LINT!')
