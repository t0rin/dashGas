from dash import Dash, html, dcc, callback, Output, Input
import plotly.express as px
import pandas as pd

df = pd.read_csv('gasLog.csv')
columns = ['DateStamp', 'Time', 'Price', 'Address', 'City']
df.columns = columns
df['Date'] = pd.to_datetime(df['DateStamp'], format='%Y%m%d')

app = Dash()

app.layout = [
    html.H1(children='East Bay Costco Gas Prices', style={'textAlign':'center'}),
    dcc.Graph(id='graph-content'),
    dcc.Checklist(
        id='checklist',
        options=df.City.unique(),
        value=['NEWARK'],
        inline=True
    )
]

@callback(
    Output('graph-content', 'figure'),
    Input('checklist', 'value')
)
def update_graph(value):
    dff = df.City.isin(value)
    return px.line(df[dff], x='Date', y='Price', color='City')

if __name__ == '__main__':
    app.run(debug=True)
