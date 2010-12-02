##
# super controller for the redmine RE plugin
# common methods used for (almost) all redmine_re controllers go here
class RedmineReController < ApplicationController
  unloadable
  
  #include ActionView::Helpers::UrlHelper
  #include ActionView::Helpers::AssetTagHelper
  #include ActionView::Helpers::TagHelper  

  before_filter :find_project
  #before_filter :authorize,
               # :except =>  [:delegate_tree_drop, :delegate_tree_node_click]

  # uses redmine_re in combination with redmines base layout for the header unless it is an ajax-request
  layout proc{ |c| c.request.xhr? ? false : "redmine_re" } 
  
  # marks 'Requirements' (css class=re) as the selected menu item
  menu_item :re

  def find_project
    # find the current project either by project name (project id entered by the user) or id
    project_id = params[:project_id]
    return unless project_id
    begin
      @project = Project.find(project_id)
    #rescue ActiveRecord::RecordNotFound
      #render_404
    end
  end

  def save_re_tree_structure
    @treestructure = params[:treestructure]
  end

  def add_hidden_re_artifact_properties_attributes re_artifact
    # this adds user-unmodifiable attributes to the re_artifact_properties
    # the re_artifact_properties is a superclass of all other artifacts (goals, tasks, etc)
    # this method should be called after initializing or loading any artifact object
    author = find_current_user
    re_artifact.project_id = @project.id
    re_artifact.updated_at = Time.now
    re_artifact.updated_by = author.id
    re_artifact.created_by = author.id  if re_artifact.new_record?
  end
  
  def create_tree
    artifacts = ReArtifactProperties.find_all_by_project_id(@project.id)
    # artifacts = [] if artifacts.nil?

    htmltree = '<ul id="tree">'
    for artifact in artifacts
      if (artifact.parent.nil?)
        htmltree += render_to_html_tree(artifact)
      end
    end
    htmltree += '</ul>'
    
    htmltree
  end
  

  ##
  # The following method is called via JavaScript Tree by an ajax request.
  # It transmits the drops done in the tree to the database in order to last
  # longer than the next refresh of the browser.
  def delegate_tree_drop
    new_parent_id = params[:new_parent_id]
    moved_artifact_id = params[:moved_artifact_id]
    child = ReArtifactProperties.find_by_id(moved_artifact_id)
    if new_parent_id == 'null'
      # Element is dropped under root node which is the project new parent-id has to become nil.
      child.parent = nil
    else
      # Element is dropped under other artifact
      child.parent = ReArtifactProperties.find(new_parent_id)
    end
    child.state = State::DROPPING    #setting state for observer
    child.save!
    render :nothing => true
  end

  ##
  # The following method is called via JavaScript Tree by an ajax update request.
  # It transmits the call to the according controller which should render the detail view
  def delegate_tree_node_click
    artifact = ReArtifactProperties.find_by_id(params[:id])
    redirect_to url_for :controller => params[:artifact_controller], :action => 'edit', :id => params[:id], :parent_id => artifact.parent_artifact_id, :project_id => artifact.project_id
  end

  #renders a re artifact and its children recursively as html tree
  def render_to_html_tree(re_artifact)
    artifact_type = re_artifact.artifact_type.to_s.underscore
    htmltree = ''
    htmltree += '<li id="node_' + re_artifact.id.to_s #IDs must begin with a letter(!)
    htmltree += '" class="' + artifact_type
    if re_artifact.children.empty?
      htmltree += ' closed'
    end
    htmltree += '">'
    htmltree += '<span class="handle"></span>'
    htmltree += '<a class="nodelink">' + re_artifact.name.to_s + '</a>'
    htmltree += '<a href="' + url_for( :controller => artifact_type, :action => 'edit', :id => re_artifact.artifact_id) + '" class="nodeeditlink">(' + l(:re_edit) + ')</a>'

    if (!re_artifact.children.empty?)
      htmltree += '<ul>'
      for child in re_artifact.children
        htmltree += render_to_html_tree(child)
      end
      htmltree += '</ul>'
    end
    htmltree += '</li>'
  end
  
  def treestate
    if params[:open] == 'true'
      re_artifact_properties =  params[:id]    
    end

    render :nothing => true   
  end

  # first tries to enable a contextmenu in artifact tree
  def context_menu
    @artifact =  ReArtifactProperties.find_by_id(params[:id])

    render :text => "Could not find artifact.", :status => 500 unless @artifact

    @subartifact_controller = @artifact.artifact_type.to_s.underscore
    @back = params[:back_url] || request.env['HTTP_REFERER']

    render :layout => false
  end
end