var NewProjectButton = React.createClass({
  handleClick: function() {
     React.render(
       <ProjectForm {...this.props} />
      , document.getElementById('projectFormTarget'));
      $("#ProjectFormModal").modal('toggle');
  },

  render: function() {
    return (
      <a className="NewProjectButton" onClick={this.handleClick}>
        <i className="fa fa-plus-circle fa-2x" />{this.props.label}
      </a>
    )
  }
});
