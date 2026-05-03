from flask import Flask, request, jsonify
import sqlite3

app = Flask(__name__)
app.json.sort_keys = False
DB_PATH = "golf.db"


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def parse_list(value):
    if not value:
        return []
    return [x.strip() for x in value.split(",") if x.strip()]


@app.get("/user-stats")
def get_user_stats():
    countries = parse_list(request.args.get("countries"))
    oss = parse_list(request.args.get("oss"))

    if oss:
        sql = """
        SELECT
            username,
            country,
            fav_map,
            fav_map_win_ratio,
            total_playtime,
            total_win_ratio,
            avg_matches_per_session,
            registration_date
        FROM user_stats_os
        """
        params = []
        conditions = []

        if countries:
            placeholders = ",".join(["?"] * len(countries))
            conditions.append(f"country IN ({placeholders})")
            params.extend(countries)

        placeholders = ",".join(["?"] * len(oss))
        conditions.append(f"device_os IN ({placeholders})")
        params.extend(oss)

        if conditions:
            sql += " WHERE " + " AND ".join(conditions)

        sql += " ORDER BY total_playtime DESC"

    else:
        sql = """
        SELECT
            username,
            country,
            fav_map,
            fav_map_win_ratio,
            total_playtime,
            total_win_ratio,
            avg_matches_per_session,
            registration_date
        FROM user_stats_all
        """
        params = []

        if countries:
            placeholders = ",".join(["?"] * len(countries))
            sql += f" WHERE country IN ({placeholders})"
            params.extend(countries)

        sql += " ORDER BY total_playtime DESC"

    conn = get_conn()
    rows = conn.execute(sql, params).fetchall()
    conn.close()

    return jsonify([dict(row) for row in rows])


@app.get("/map-stats/<map_name>")
def get_map_stats(map_name):
    date_from = request.args.get("date_from")
    date_to = request.args.get("date_to")

    conn = get_conn()

    # nadji map_id iz imena mape
    map_row = conn.execute(
        "SELECT map_id FROM raw_maps WHERE map_name = ?",
        (map_name,)
    ).fetchone()

    if map_row is None:
        conn.close()
        return jsonify({"error": f"Mapa '{map_name}' ne postoji"}), 404

    map_id = map_row["map_id"]

    sql = """
        SELECT
            date,
            avg_playtime,
            best_player_username,
            match_cnt
        FROM map_stats
        WHERE map_id = ?
    """
    params = [map_id]

    if date_from:
        sql += " AND date >= ?"
        params.append(date_from)

    if date_to:
        sql += " AND date <= ?"
        params.append(date_to)

    sql += " ORDER BY date DESC"

    rows = conn.execute(sql, params).fetchall()
    conn.close()

    return jsonify([dict(row) for row in rows])





@app.get("/chart-data")
def get_chart_data():
    conn = get_conn()

    sql = """
        SELECT
            RM.map_name,
            MS.date,
            MS.match_cnt
        FROM map_stats MS
        JOIN raw_maps RM
            ON RM.map_id = MS.map_id
        WHERE MS.date >= (
            SELECT date(MAX(date), '-6 day') FROM map_stats
        )
        ORDER BY MS.date ASC, RM.map_name ASC
    """

    rows = conn.execute(sql).fetchall()
    conn.close()

    return jsonify([dict(row) for row in rows])

@app.get("/chart")
def chart():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Map Match Count - Last 7 Days</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    </head>
    <body>
        <h2>Match count by map - last 7 days</h2>
        <canvas id="myChart" width="900" height="400"></canvas>

        <script>
            async function drawChart() {
                const response = await fetch('/chart-data');
                const data = await response.json();

                const allDates = [...new Set(data.map(row => row.date))];
                const allMaps = [...new Set(data.map(row => row.map_name))];

                const datasets = allMaps.map(mapName => {
                    const values = allDates.map(date => {
                        const row = data.find(r => r.map_name === mapName && r.date === date);
                        return row ? row.match_cnt : 0;
                    });

                    return {
                        label: mapName,
                        data: values,
                        fill: false,
                        tension: 0.1
                    };
                });

                new Chart(document.getElementById('myChart'), {
                    type: 'line',
                    data: {
                        labels: allDates,
                        datasets: datasets
                    },
                    options: {
                        responsive: true,
                        plugins: {
                            legend: {
                                display: true
                            }
                        },
                        scales: {
                            y: {
                                beginAtZero: true
                            }
                        }
                    }
                });
            }

            drawChart();
        </script>
    </body>
    </html>
    """



if __name__ == "__main__":
    app.run(debug=True)