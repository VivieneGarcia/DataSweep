from flask import Flask, request, jsonify
import pandas as pd
import io

app = Flask(__name__)

@app.route('/remove_duplicates', methods=['POST'])
def remove_duplicates():
    print("Request received!")

    data = request.get_json()
    file_contents = data.get('file_contents')

    if file_contents is None:
        return jsonify({'error': 'No file contents provided'}), 400

    # Read the CSV data from the string
    df = pd.read_csv(io.StringIO(file_contents))

    # Remove duplicates
    cleaned_df = df.drop_duplicates()

    # Convert cleaned DataFrame to CSV string
    output = io.StringIO()
    cleaned_df.to_csv(output, index=False)
    cleaned_csv = output.getvalue()

    return jsonify({'message': 'Duplicates removed successfully', 'cleaned_csv': cleaned_csv}), 200

if __name__ == '__main__':
    app.run(debug=True)
