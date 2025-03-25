import os

from flask import Flask, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy


app = Flask(__name__)


# CONN_STRING is the string needed to connect to the database and
# be of the format $USERNAME:$PASSWORD@HOSTNAME:$DB_PORT_NUMBER
DBUSER = os.environ.get("DBUSER", "postgres")
DBPASSWD = f':{os.environ.get("DBPASSWD")}' if os.environ.get("DBPASSWD") else ""
DBHOST = os.environ.get("DBHOST")
DBPORT = os.environ.get("DBPORT", "5432")
CONN_STRING = f"{DBUSER}{DBPASSWD}@{DBHOST}:{DBPORT}"
app.config["SQLALCHEMY_DATABASE_URI"] = f"postgresql://{CONN_STRING}/todo"
db = SQLAlchemy(app)


class TodoList(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    completed = db.Column(db.Boolean, nullable=False, default=False)


with app.app_context():
    db.create_all()


@app.route("/")
def home():
    # request all todos, limited to the oldest 250
    todo_list = TodoList.query.order_by("id").limit(250).all()
    return render_template("base.html", todo_list=todo_list)


@app.route("/add", methods=["POST"])
def add():
    # add new todo item
    name = request.form.get("name")
    if name:
        new_todo = TodoList(name=name, completed=False)
        db.session.add(new_todo)
        db.session.commit()
    return redirect(url_for("home"))


@app.route("/update/<int:todo_id>", methods=["GET"])
def update(todo_id):
    # toggle status of item
    todo = TodoList.query.filter_by(id=todo_id).first()
    todo.completed = not todo.completed
    db.session.commit()
    return redirect(url_for("home"))


@app.route("/delete/<int:todo_id>", methods=["GET"])
def delete(todo_id):
    # delete item
    todo = TodoList.query.filter_by(id=todo_id).first()
    db.session.delete(todo)
    db.session.commit()
    return redirect(url_for("home"))


if __name__ == "__main__":
    debug = os.environ.get("DEBUG", False)
    app.run(host="0.0.0.0", port=5000, debug=debug)

