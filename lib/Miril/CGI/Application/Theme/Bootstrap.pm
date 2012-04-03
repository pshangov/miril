package Miril::CGI::Application::Theme::Bootstrap;

# ABSTRACT: Web UI theme based on Twitter Bootstrap

use strict;
use warnings;

use base 'Template::Declare';
use Template::Declare::Tags 'HTML';
use URI::Query;

sub uri { '?' . URI::Query->new(@_)->stringify } 

BEGIN { create_wrapper wrap => sub {
    my ( $code, $current ) = @_;
    $current = '' unless $current;

    outs_raw '<!DOCTYPE html>';

    html {
        head {
            meta { attr { charset => "utf-8" } }
            title { "Miril" }
            
            my @stylesheets = (
                "http://twitter.github.com/bootstrap/assets/css/bootstrap.css",
                "http://twitter.github.com/bootstrap/assets/css/bootstrap-responsive.css",
            );

            foreach my $stylesheet (@stylesheets) {
                link { attr { href => $stylesheet, rel => "stylesheet" } }
            }

            style { "body { padding-top: 60px; }" }
        }

        body { 
            div { attr { class => "navbar navbar-fixed-top" }
                div { attr { class => "navbar-inner" }
                    div { attr { class => "container" }
                        a { attr { class => "brand", href  => uri( action => 'list' ) } "Miril" }
                        div { attr { class => "nav-collapse" }
                            ul { 
                                attr { class => "nav" };

                                foreach my $section (qw(list search create publish)) {
                                    li { 
                                        attr { class => "active" } if $section eq $current;
                                        a { attr { href => uri( action => $section ) } ucfirst $section };
                                    };
                                }

            } } } } } 

            div { attr { class => "container" }  
                $code->();
            }
        }
    }
} }

template list => sub {
    my ($self, $posts, $pager, $uri_callback) = @_;

    wrap {
        h1 { "List posts" }

        table { attr { class => "table table-striped table-bordered table-condensed" }

            thead { row { th { "Name" } th { "Type" } th { "Date" } } }

            tbody {
                foreach my $post (@$posts) {
                    row {
                        cell { a { attr { href => uri( action => 'display', id => $post->id ) } $post->title } }
                        cell { span { attr { class => "label" } $post->type->name } }
                        cell { $post->modified->as_ymdhm }
        } } } }; 
        
        if ($pager) {
            div { attr { class => "pagination" }
                ul {
                    li { a { attr { href => $uri_callback->($pager->first_page) } "First" } };
                    
                    foreach my $page ($pager->pages_in_navigation) {
                        if ( $pager->current_page == $page ) {
                            li { attr { class => "active" } a { attr { href => "#" } $page } }
                        } else {
                            li { a { attr { href => $uri_callback->($page) } $page } }
                        }
                    }

                    li { a { attr { href => $uri_callback->($pager->last_page) } "Last" } }
        } } } 
    } 'list';
};


template search => sub {
    my ($self, $taxonomy) = @_;

    wrap {
        h1 { "Search posts" }

        form { attr { class => 'horizontal' }
            fieldset {

                div { attr { class => 'control-group' } 
                    label { 
                        attr { class => 'control-label', for => 'title' } 
                        "Title contains" 
                    }
                    div { attr { class => 'controls' } 
                        input { attr {
                                type  => 'text',
                                class => 'input-xlarge',
                                id    => 'title',
                                name  => 'title',
                } } } }

                div { attr { class => 'control-group' } 
                    label { 
                        attr { class => 'control-label', for => 'type' } 
                        "Type" 
                    }
                    div { attr { class => 'controls' } 
                        select { attr {
                                class => 'input-xlarge',
                                id    => 'title',
                                name  => 'type',
                            }

                            option { attr { value => '' } '--Any--' };
                            foreach my $type ($taxonomy->get_types) {
                                option { attr { value => $type->id } $type->name }
                } } } };

                if ($taxonomy->has_authors) {
                    div { attr { class => 'control-group' } 
                        label { 
                            attr { class => 'control-label', for => 'author' } 
                            "Author" 
                        }
                        div { attr { class => 'controls' } 
                            select { attr {
                                    class => 'input-xlarge',
                                    id    => 'author',
                                    name  => 'author',
                                }

                                option { attr { value => '' } '--Any--' };
                                foreach my $author ($taxonomy->get_authors) {
                                    option { attr { value => $author->id } $author->name }
                } } } }; }

                div { attr { class => 'control-group' } 
                    label { 
                        attr { class => 'control-label', for => 'status' } 
                        "Status" 
                    }
                    div { attr { class => 'controls' } 
                        select { attr {
                                class => 'input-xlarge',
                                id    => 'status',
                                name  => 'status',
                            }

                            option { attr { value => ''          } '--Any--' }
                            option { attr { value => 'published' } 'Published' }
                            option { attr { value => 'draft'     } 'Draft' }
                } } };

                if ($taxonomy->has_topics) {
                    div { attr { class => 'control-group' } 
                        label { 
                            attr { class => 'control-label', for => 'topic' } 
                            "Topic" 
                        }
                        div { attr { class => 'controls' } 
                            select { attr {
                                    class => 'input-xlarge',
                                    id    => 'topic',
                                    name  => 'topic',
                                }

                                option { attr { value => '' } '--Any--' };
                                foreach my $topic ($taxonomy->get_topics) {
                                    option { attr { value => $topic->id } $topic->name }
                } } } }; }

                button { attr { 
                    name  => 'action', 
                    value => 'list',
                    class => 'btn btn-primary',
                    type  => 'submit',
                } 'Search' }

    } } } 'search';
};

template edit => sub {
    my ($self, $taxonomy, $invalid) = @_;

    my %control_group = map { 
        $_ => ( $invalid->{$_} ? 'control-group error' : 'control-group' ) 
    } qw(
        id
        title
        type
        author
        status
        topics
        source
    );

    wrap {
        h1 { "Edit post" }

        form { attr { class => 'horizontal', method => 'POST' }
            fieldset {

                div { attr { class => $control_group{title} } 
                    label { 
                        attr { class => 'control-label', for => 'title' } 
                        "Title" 
                    }
                    div { attr { class => 'controls' } 
                        input { attr {
                                type  => 'text',
                                class => 'input-xlarge',
                                id    => 'title',
                                name  => 'title',
                } } } }

                div { attr { class => $control_group{id} } 
                    label { 
                        attr { class => 'control-label', for => 'id' } 
                        "ID" 
                    }
                    div { attr { class => 'controls' } 
                        input { attr {
                                type  => 'text',
                                class => 'input-xlarge',
                                id    => 'id',
                                name  => 'id',
                } } } }

                div { attr { class => $control_group{type} } 
                    label { 
                        attr { class => 'control-label', for => 'type' } 
                        "Type" 
                    }
                    div { attr { class => 'controls' } 
                        select { attr {
                                class => 'input-xlarge',
                                id    => 'title',
                                name  => 'type',
                            };

                            foreach my $type ($taxonomy->get_types) {
                                option { attr { value => $type->id } $type->name }
                } } } };

                if ($taxonomy->has_authors) {
                    div { attr { class => $control_group{author} } 
                        label { 
                            attr { class => 'control-label', for => 'author' } 
                            "Author" 
                        }
                        div { attr { class => 'controls' } 
                            select { attr {
                                    class => 'input-xlarge',
                                    id    => 'author',
                                    name  => 'author',
                                };

                                option { attr { value => '' } 'N/A' };
                                foreach my $author ($taxonomy->get_authors) {
                                    option { attr { value => $author->id } $author->name }
                } } } }; }

                div { attr { class => $control_group{status} } 
                    label { 
                        attr { class => 'control-label', for => 'status' } 
                        "Status" 
                    }
                    div { attr { class => 'controls' } 
                        select { attr {
                                class => 'input-xlarge',
                                id    => 'status',
                                name  => 'status',
                            }

                            option { attr { value => 'draft'     } 'Draft' }
                            option { attr { value => 'published' } 'Published' }
                } } };

                if ($taxonomy->has_topics) {
                    div { attr { class => $control_group{topics}  } 
                        label { 
                            attr { class => 'control-label', for => 'topics' } 
                            "Topics" 
                        }
                        div { attr { class => 'controls' } 
                            select { attr {
                                    class    => 'input-xlarge',
                                    id       => 'topics',
                                    name     => 'topics',
                                    size     => 3,
                                    multiple => 1,
                                };

                                foreach my $topic ($taxonomy->get_topics) {
                                    option { attr { value => $topic->id } $topic->name }
                } } } }; }

                div { attr { class => $control_group{topics} } 
                    label { 
                        attr { class => 'control-label', for => 'source' } 
                        "Body" 
                    }
                    div { attr { class => 'controls' } 
                        textarea { attr {
                                class => 'input-xlarge',
                                id    => 'source',
                                name  => 'source',
                                rows  => 10,
                                cols  => 20,
                } } } }

                 div { attr { class => 'controls' } 
                        input { attr {
                                type  => 'hidden',
                                class => 'input-xlarge',
                                id    => 'old_id',
                                name  => 'old_id',
                } } }

                button { attr { 
                    name  => 'action', 
                    value => 'update',
                    class => 'btn btn-primary',
                    type  => 'submit',
                } 'Save' }

                button { attr { 
                    name  => 'action', 
                    value => 'delete',
                    class => 'btn',
                    type  => 'submit',
                } 'Delete' }

                button { attr { 
                    name  => 'action', 
                    value => 'display',
                    class => 'btn',
                    type  => 'submit',
                } 'Cancel' }

    } } } 'create';

};

template error => sub {
    my ($self, $e) = @_;
    p { $e }
};

template display => sub {
    my ( $self, $post )  = @_;

    wrap {
        h1 { $post->title }
        div { outs_raw( $post->body ) }
        a { attr { class => 'btn', href => uri ( action => 'edit', id => $post->id ) } 'Edit' }
        a { attr { class => 'btn', href => uri ( action => 'list' ) } 'Cancel' }
    }
};

template publish => sub {
    my ( $self, $post )  = @_;

    wrap {
        h1 { 'Publish' }
        a { attr { class => 'btn', href => uri ( action => 'publish' ) } 'Publish' }
        a { attr { class => 'btn', href => uri ( action => 'list' ) } 'Cancel' }
    } 'publish';
};

1;
