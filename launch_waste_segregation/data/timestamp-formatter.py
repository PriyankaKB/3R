import pandas as pd

df = pd.read_csv("mcp-feedback-data.csv")
df['timestamp'] = pd.to_datetime(df['timestamp'], dayfirst=True).dt.strftime('%YYYY-%mm-%dd')
df.to_csv("mcp-feedback-data.csv", index=False)
