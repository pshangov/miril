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
            title { "Miril" };
            
            foreach my $stylesheet (@{ __PACKAGE__->stash->{css} }) {
                link { attr { href => $stylesheet, rel => "stylesheet" } };
            }

            style { "body { padding-top: 60px; }" }
        }

        body { 
            div { attr { class => "navbar navbar-fixed-top" }
                div { attr { class => "navbar-inner" }
                    div { attr { class => "container" }
                        a { attr { class => "brand", href  => uri( action => 'list' ) } __PACKAGE__->stash->{name} }
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

            thead { row { th { "Name" } th { "Type" } th {  attr { style => "text-align: right"}
"Date" } } }

            tbody {
                foreach my $post (@$posts) {
                    row {
                        cell { a { attr { href => uri( action => 'display', id => $post->id ) } $post->title } }
                        cell { span { $post->type->name } }
                        #cell { span { attr { class => "label" } $post->type->name } }
                        cell { attr { style => "text-align: right"}
                            $post->is_published 
                                ? $post->published->as_strftime("%d %B %Y, %H:%M")
                                : '(' . $post->modified->as_strftime("%d %B %Y, %H:%M") . ')'
                        }
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

                button { attr { 
                    name  => 'action', 
                    value => 'list',
                    class => 'btn btn-primary',
                    type  => 'submit',
                } 'Search' }

    } } } 'search';
};

template create => sub {
    my ($self, $taxonomy) = @_;

    wrap {
        h1 { "Create new post" }

        ul {
            foreach my $type ($taxonomy->get_types) {
                li { a { attr { 
                    href => uri( action => 'edit', type => $type->id )
                } $type->name } }
            }
        }

    } 'create';
};

template edit => sub {
    my ($self, $taxonomy, $fields, $invalid) = @_;

    my %control_group = map { 
        $_ => ( $invalid->{$_} ? 'control-group error' : 'control-group' ) 
    } qw(id title type status source), map { $_->name } @$fields;

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

                foreach my $field ( @$fields ) {
                    div { attr { class => 'control-group' } 
                        label { 
                            attr { class => 'control-label', for => $field->id } 
                            $field->name 
                        }
                        div { attr { class => 'controls' } 
                            outs_raw $field->render;
                } }; }

                div { attr { class => $control_group{source} } 
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

                input { attr { type => 'hidden', id => 'old_id', name => 'old_id' } } 
                input { attr { type => 'hidden', id => 'type', name => 'type' } }
                
                div { attr { class => 'form-actions' }
                    button { attr { 
                        name  => 'action', 
                        value => 'update',
                        class => 'btn btn-primary',
                        type  => 'submit',
                    } 'Save' }

                    button { attr { 
                        name  => 'action', 
                        value => 'delete',
                        class => 'btn btn-danger',
                        type  => 'submit',
                    } 'Delete' }

                    button { attr { 
                        name  => 'action', 
                        value => 'display',
                        class => 'btn',
                        type  => 'submit',
                    } 'Cancel' }
                }

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
        div { attr { class => 'form-actions' }
            a { attr { class => 'btn btn-primary', href => uri ( action => 'edit', id => $post->id ) } 'Edit' }
            a { attr { class => 'btn', href => uri ( action => 'list' ) } 'Cancel' }
        }
    } 'list';
};

template publish => sub {
    my ( $self, $post )  = @_;

    wrap {
        h1 { 'Publish' }
        a { attr { class => 'btn btn-primary', href => uri ( action => 'publish' ) } 'Publish' }
        a { attr { class => 'btn', href => uri ( action => 'list' ) } 'Cancel' }
    } 'publish';
};

1;
