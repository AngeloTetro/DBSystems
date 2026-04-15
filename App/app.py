from datetime import datetime

from flask import Flask, flash, redirect, render_template, request, url_for

import database

app = Flask(__name__)
app.secret_key = "stageup-secret-key"


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/register_customer", methods=["GET", "POST"])
def register_customer():
    if request.method == "POST":
        conn = None
        cur = None
        try:
            conn = database.get_connection()
            cur = conn.cursor()
            cur.callproc(
                "proc_register_customer",
                [
                    request.form.get("customer_code"),
                    request.form.get("phone"),
                    request.form.get("email"),
                    request.form.get("customer_type"),
                    request.form.get("first_name") or None,
                    request.form.get("last_name") or None,
                    request.form.get("company_name") or None,
                ],
            )
            conn.commit()
            flash("Customer registered successfully", "success")
        except Exception as exc:
            flash(f"Error: {exc}", "error")
        finally:
            if cur:
                cur.close()
            if conn:
                conn.close()
        return redirect(url_for("register_customer"))

    return render_template("register_customer.html")


@app.route("/add_event_location", methods=["GET", "POST"])
def add_event_location():
    if request.method == "POST":
        conn = None
        cur = None
        try:
            conn = database.get_connection()
            cur = conn.cursor()
            cur.callproc(
                "proc_add_event_location",
                [
                    request.form.get("location_code"),
                    request.form.get("customer_code"),
                    request.form.get("street"),
                    request.form.get("house_number"),
                    request.form.get("postal_code"),
                    request.form.get("city"),
                    request.form.get("province"),
                    int(request.form.get("setup_time_est")),
                    int(request.form.get("equipment_capacity")),
                ],
            )
            conn.commit()
            flash("Event location inserted successfully", "success")
        except Exception as exc:
            flash(f"Error: {exc}", "error")
        finally:
            if cur:
                cur.close()
            if conn:
                conn.close()
        return redirect(url_for("add_event_location"))

    return render_template("add_event_location.html")


@app.route("/add_booking", methods=["GET", "POST"])
def add_booking():
    if request.method == "POST":
        conn = None
        cur = None
        try:
            conn = database.get_connection()
            cur = conn.cursor()
            booking_date = datetime.strptime(request.form.get("booking_date"), "%Y-%m-%d")
            cur.callproc(
                "proc_add_booking",
                [
                    request.form.get("booking_code"),
                    request.form.get("booking_type"),
                    booking_date,
                    int(request.form.get("duration_days")),
                    float(request.form.get("cost")),
                    request.form.get("customer_code"),
                    request.form.get("location_code"),
                    request.form.get("team_code"),
                    request.form.get("booking_channel") or "website",
                    "HQ1",
                ],
            )
            conn.commit()
            flash("Booking inserted successfully", "success")
        except Exception as exc:
            flash(f"Error: {exc}", "error")
        finally:
            if cur:
                cur.close()
            if conn:
                conn.close()
        return redirect(url_for("add_booking"))

    return render_template("add_booking.html")


@app.route("/view_location_team", methods=["GET", "POST"])
def view_location_team():
    result = None
    if request.method == "POST":
        conn = None
        cur = None
        try:
            conn = database.get_connection()
            cur = conn.cursor()
            result = cur.callfunc(
                "func_get_team_by_location",
                str,
                [request.form.get("customer_code"), request.form.get("location_code")],
            )
        except Exception as exc:
            result = f"Error: {exc}"
        finally:
            if cur:
                cur.close()
            if conn:
                conn.close()

    return render_template("view_location_team.html", result=result)


@app.route("/ranked_locations")
def ranked_locations():
    conn = None
    cur = None
    rows = []
    try:
        conn = database.get_connection()
        cur = conn.cursor()
        cur.execute("SELECT LocationCode, BookingCount FROM vw_ranked_locations")
        rows = cur.fetchall()
    except Exception as exc:
        flash(f"Error: {exc}", "error")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    return render_template("ranked_locations.html", rows=rows)


if __name__ == "__main__":
    app.run(debug=True)
