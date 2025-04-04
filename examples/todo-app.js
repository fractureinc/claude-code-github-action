// Simple Todo App with several improvement opportunities
class TodoApp {
  constructor() {
    this.todos = [];
    this.currentId = 0;
  }
  
  // Add a new todo with a specific title
  addTodo(title) {
    const todo = {
      id: this.currentId++,
      title: title,
      completed: false,
      createdAt: new Date()
    };
    
    this.todos.push(todo);
    return todo.id;
  }
  
  // Very simple getting of todos with no filtering options
  getTodos() {
    return this.todos;
  }
  
  // Mark a todo as complete
  completeTodo(id) {
    var found = false;
    for (var i = 0; i < this.todos.length; i++) {
      if (this.todos[i].id == id) {
        this.todos[i].completed = true;
        found = true;
        break;
      }
    }
    return found;
  }
  
  // Delete a todo
  deleteTodo(id) {
    var index = -1;
    for (var i = 0; i < this.todos.length; i++) {
      if (this.todos[i].id == id) {
        index = i;
        break;
      }
    }
    
    if (index !== -1) {
      this.todos.splice(index, 1);
      return true;
    }
    return false;
  }
  
  // Not very useful function that counts completed todos
  countCompleted() {
    var count = 0;
    for (var i = 0; i < this.todos.length; i++) {
      if (this.todos[i].completed) {
        count++;
      }
    }
    return count;
  }
  
  // Print all todos to console
  printTodos() {
    console.log("==== TODO LIST ====");
    for (var i = 0; i < this.todos.length; i++) {
      var todo = this.todos[i];
      var status = todo.completed ? "[DONE]" : "[TODO]";
      console.log(`${status} ${todo.id}: ${todo.title}`);
    }
    console.log("==================");
  }
}

module.exports = TodoApp;